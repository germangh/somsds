#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: SOMSDS controller module
# Documentation: core_stuff.txt


package SOMSDS;
use SOMSDS::Recording;
use SOMSDS::File;

use Term::ANSIColor qw(:constants);
use Carp;
use Cwd 'abs_path';
use List::MoreUtils qw(none any);
use Config::IniFiles;
use File::Basename;
use File::Spec::Functions;
use File::Path qw(make_path);
use File::Find;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use Time::Format qw(%time);
use Tie::Handle::CSV;
use Archive::Tar;
use DBI;

#use 5.014001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use SOMSDS ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

# Read configuration file SOMSDS.ini
my ($vol, $dir, $file) = File::Spec->splitpath($0);
my $somsds_cfg_file; 
if ($vol){
  $somsds_cfg_file = abs_path catfile($vol, $dir,'SOMSDS.ini');
} else {
  $somsds_cfg_file = abs_path catfile($dir,'SOMSDS.ini');
}

unless (-e $somsds_cfg_file){
  $somsds_cfg_file = '/etc/SOMSDS.ini'; 
} 
 
my $somsds_cfg = new Config::IniFiles(-file => $somsds_cfg_file);

########################################################## PUBLIC STATIC METHODS



# Creates a new SOMSDS object. Initializes it using database info, if available.
sub new {

  my $class = shift;

  my $root_path = shift;
  
  my %fields = (
    root_path   => undef,
    db_folder   => undef,
    arc_folder  => undef,
    rec_folder  => undef,
    proj_folder => undef,
    rec_path    => undef,
    db_path     => undef,
    proj_path   => undef,
    rec_csv     => undef,
    subj_csv    => undef,
    files_csv   => undef,
  	file        => {},  # Keys are full path names, values are File objects
  	recording   => {},  # Keys are recordings ids, values are Recording objects
	);
	
  my $self = {        
    _dbh       => undef, # A CSV database object
    _permitted => \%fields,
    %fields,
  };

  # Read object properties from the configuration file
  for (qw(root_path arc_folder db_folder rec_folder proj_folder rec_csv subj_csv files_csv)){
    $self->{$_} = $somsds_cfg->val('somsds', $_);
  }

  # For testing purposes
  if ($root_path) {
    $self->{root_path} = $root_path;	
  }

  # Some convenient properties
  $self->{rec_path}   = catdir($self->{root_path}, $self->{rec_folder});
  $self->{proj_path}  = catdir($self->{root_path}, $self->{proj_folder});
  $self->{db_path}    = catdir($self->{root_path}, $self->{db_folder});

  # Make folder structure
  my $options = {mode => 0777, verbose => 1};
  foreach (qw(rec_folder proj_folder db_folder)){   
    my $new_dir = catdir($self->{root_path}, 
                         $self->{$_});
    make_path $new_dir, $options;
  }

  bless $self, $class;   

  # Generate CSV tables, if they don't exist
  $self->_make_csv_tables();

  # Load CSV tables
  $self->_load(); 
  return $self;
}  


#####################


# Adds file extension to a set of files
sub add_file_ext{
  my ($regex, $filext, $root) = (shift, shift, shift);

	
  # Search for files that need to be described within the directory tree    
  find(sub {_rename($File::Find::name, $regex, $filext)}, $root); 
  print RED, "Do you want to rename the files above [y/n]? ", RESET;
  my $choice = <STDIN>;
  chomp $choice;
  unless ($choice eq "y"){
    die "Nothing done!\n";
  }  
	finddepth(sub {_rename($File::Find::name, $regex, $filext, 1)}, $root);         
}

#####################

# Unzips files recursively using OGE
sub gunzip{
  my ($root, $regex, $oge) = (shift, shift, shift);

  finddepth(sub{_gunzip($File::Find::name, $regex, $oge)}, $root);
  
}

sub _gunzip {
  my ($fname, $regex, $oge) = (shift, shift, shift);
  if ($regex){
    return unless ($fname =~ m%$regex%);
  }
  return unless ($fname =~ m%.gz$%);
  if ($oge){
    system("echo '/bin/gunzip -vf $fname' | qsub");
  } else {
    system("gunzip -vf $fname");
  }
}


######################

sub _rename {
  my ($fname, $regex, $filext, $rename) = (shift, shift, shift, shift);
  return unless ($fname =~ m%$regex%);
  return if ($fname =~ m%\.$filext$%);
  return unless (-e $fname || -d $fname);
  my $new_name = $fname.$filext;
	print "$fname\n--->$new_name\n\n";
  if ($rename){   
    rename($File::Find::name, $new_name);
  }
} 

####################


# Generates table headers
sub _header {
  my $csv_table = shift;
  my $quotes    = $somsds_cfg->val('somsds', 'quotes');
  my $separator = $somsds_cfg->val('somsds', 'separator');
  my %header    = ( rec_csv   =>  ["id", "uname", "date", "archived", "settings"],                    
                    subj_csv  =>  ["id", "uname", "date", "recording", "sex",
                                   "age", "group", "meta"],
                    files_csv =>  ["id", "uname", "date", "recording", "subject",
                                   "sex","age","group","modality","device",
                                   "technique","condition","session","block","meta"],                 
                  ); 
  my $header = join $separator, map {qq/$quotes$_$quotes/} @{$header{$csv_table}};
}


####################


# Generates a new recording configuration file
sub new_rec_settings {
  my $options = shift;

  if (-e $options->{filename}){
    croak "File ".$options->{filename}." already exists!\n";
  }

  my $settings = Config::IniFiles->new();
  $settings->SetFileName($options->{filename}) || 
    croak "I could not create file ".$options->{filename}."\n";

  unless ($options->{recid}){
    croak "A recording ID must be provided";
  }

  # Recording secion
  my $rec = "recording ".$options->{recid};
  $settings->AddSection($rec);
  for (qw(description responsible)){
    $settings->newval($rec, $_, $options->{$_});
  }
  
  # Modalities, conditions, subjects
  for my $group (qw(modality condition subject technique device session
                    block)){
    for my $group_member (@{$options->{$group}}){
      $settings->AddSection($group." ".$group_member); 
      for my $prop_name (@{$options->{"$group"."_props"}}){
        $settings->newval($group." ".$group_member, $prop_name, '');
      }
    }
  }
  
  $settings->WriteConfig($options->{filename});
}

################################################################# PUBLIC METHODS

# Does the SOMSDS structure already contain a given recording?
sub contains_rec {
  my $self = shift;
  my $recid = shift;
  any {$_ eq $recid} keys %{$self->{recording}};  
}

# Removes a recording
sub remove_rec {
  my ($self, $rec) = (shift, shift);
  unless ($rec && exists($self->{recording}->{$rec})){
    croak "Invalid recording ID"  
  } 

  # Unprotect the recording
  $self->{recording}->{$rec}->unprotect(0777);

  my $rec_table = $somsds_cfg->val('somsds', 'rec_csv');
  $rec_table =~ s/\..*$//; 
  my $query = "DELETE FROM $rec_table WHERE id='$rec'";
  $self->sql($query);
  
  my $files_table = $somsds_cfg->val('somsds', 'files_csv');
  $files_table =~ s/\..*$//;  
  $query = "DELETE FROM $files_table WHERE recording='$rec'";
  $self->sql($query);
  
  print "Any reference to recording '$rec' has been removed\n";
  print "You will have to remove manually the recording directory tree\n";
}


#####################


# Archives a recording
sub archive_rec {
  my ($self, $rec, $filename) = (shift, shift, shift);

  unless ($rec){
    croak "A valid recording ID needs to be provided."  
  }

  my $rec_table = $somsds_cfg->val('somsds', 'rec_csv');
  $rec_table =~ s/\..*$//;  
  my $sth = $self->sql("SELECT * FROM $rec_table WHERE id LIKE '$rec'");
  my $row = $sth->fetchrow_hashref || croak "Recording '$rec' does not exist";
  if (lc($row->{'archived'}) eq "yes"){
    carp 
    "Warning: Recording '$rec' is already marked as archived\n";
  }
  
  unless ($filename){
    $filename = catfile($somsds_cfg->val('somsds', 'arc_folder'), 
                        $somsds_cfg->val('somsds', 'rec_folder'), 
                        $rec);
  }
  $filename = $filename.'.tgz';
  my $dirname = dirname($filename);
  unless (-e $dirname){
    make_path $dirname;
  }
  
  # Compress the whole recording tree
  my @filelist;
  my $root = $self->{recording}->{$rec}->{root_path};
  print "Archiving $root into $filename...";$|++;
  find(sub 
  	{
  		push @filelist, $File::Find::name;
  	},
    $root);
  Archive::Tar->create_archive($filename, COMPRESS_GZIP, @filelist);
  print "[done]\n";
  print "Remember to manually remove $root!\n";
  # Mark the recording as archived in the recordings table  
  $self->sql("UPDATE $rec_table SET archived='YES' WHERE id='$rec'");
  
  # Unprotect the recording
  $self->{recording}->{$rec}->unprotect();
}


#####################


# Unarchives a recording
sub unarchive_rec {
  my ($self, $rec, $filename) = (shift, shift, shift);
  unless ($rec){
    croak "A valid recording ID needs to be provided."  
  }
  my $sth = $self->sql("SELECT * FROM recordings WHERE id LIKE '$rec'");
  my $row = $sth->fetchrow_hashref || croak "Recording '$rec' does not exist";
  unless (lc($row->{'archived'}) eq "yes"){
    carp 
    "   Recording '$rec' is not marked as archived\n";
  }

  unless ($filename){
    $filename = catfile($self->{arc_folder}, $self->{rec_folder}, $rec);
  }
  $filename = $filename.'.tgz';

  # Uncompress the file
  my $tar = Archive::Tar->new($filename, COMPRESS_GZIP);
  $tar->setcwd(catdir('/'));
  $tar->extract();

  # Mark as uncompressed in the recordings table
  my $rec_table = $somsds_cfg->val('somsds','rec_csv');
  $rec_table =~ s/^(.+)\..+$/$1/;
  $self->sql("UPDATE $rec_table SET archived='NO' WHERE id='$rec'");

  # Regenerate the links (can get broken in the archiving process)
  $self->update_file_list($rec);

  # Protect the recording
  $self->{recording}->{$rec}->protect();
}


#####################

# Refreshes the list of files attached to a recording
sub update_file_list {
  my ($self, $rec) = (shift, shift); 
  unless($self->{recording}->{$rec}){
    die "Recording $rec is not found in the database. ".
        "Please run somsds_new_rec first.\n";
  }
  my $settings = $self->{recording}->{$rec}->settings();
  # Does the recording exist? has it been archived?
  my $sth = $self->sql("SELECT * FROM recordings WHERE id LIKE '$rec'");
  my $row = $sth->fetchrow_hashref || croak "Recording '$rec' does not exist";
  if (lc($row->{'archived'}) eq "yes"){
    croak 
    " Recording '$rec' is marked as archived".
    " Nothing was done!";
  }

  # What modalities, etc.. we should expect to find in the descriptor files?
  my %tests;
  for my $field (qw(modality device technique condition subject session block)){
    my @list = $settings->GroupMembers($field);
    foreach (@list){$_ =~ s/$field\s+//};
    if (@list){
      $tests{$field} = \@list; 
    }
  }
  # File extensions allowed for any modality
  my $valid_formats = $somsds_cfg->val("modality all", 'ext');
  my @valid_formats;
  if ($valid_formats){
    @valid_formats = split(/\s+/, $valid_formats);
  }

  # File formats (file extensions) that allowed for these modalities
  my %formats;
  my @valid_modalities = $somsds_cfg->GroupMembers("modality");
  foreach (@valid_modalities) {$_ =~ s/modality\s+//;}

  for my $modality (@{$tests{"modality"}}){
  	unless (any {$_ eq $modality} @valid_modalities){
		  croak 
          "Modality ''$modality'' is not listed in $somsds_cfg_file\n".
          "Listed modalities are:\n".
          join(', ', @valid_modalities);
    }
    my $valid_ext = $somsds_cfg->val("modality $modality", 'ext');
    if ($valid_ext){
      $formats{"$modality"} = [split(/\s+/, $valid_ext), @valid_formats];		   
    } else {
      $formats{"$modality"} = undef;
    }
  }

  # remove obsolete links
  $self->{recording}->{$rec}->clear_links();

  # Search for descriptor files within the recording tree, 
  # and add all the containing files to the files.csv table
  my $file_descr_regex = $somsds_cfg->val('descriptor', 'file_regexp');
  $file_descr_regex =~ s/^"(.+)"$/$1/;  
  my $root =  $self->{recording}->{$rec}->{root_path};
  my %links; # to keep track of the duplicated links  
  find(sub 
  	{
  		$self->_update_file($rec, $file_descr_regex, \%formats, \%tests, \%links);
  	},
   $root);

}

#####################

# Performs SQL queries on the database
sub sql {
  my ($self, $query) = (shift, shift); 
  if ($query =~ m/^SELECT/){   
    my $sth = $self->{_dbh}->prepare($query);
    $sth->execute();
    return $sth;
  } else {
    $self->{_dbh}->do($query, @_);
    return 1;
  }
}

#####################

# Inserts a recording into the database
sub recording {
  my ($self, $value) = (shift, shift);

  my $type = ref($self) or croak "$self is not an object";
  if ($value) {
    unless (ref($value) eq "Recording") {
      croak "$self is not an object of class Recording!"    
    }     
    my $id = $value->id();

    if ($self->{recording}->{$value->id()}){    
      if (lc($self->{recording}->{$value->id()}->archived()) eq "yes"){
        die " Recording '$id' is marked as archived. \n".
            " If you want to modify the recording, unarchive it first using:\n".
            " 'somsds_unarchive_rec $id'\n";
      }   
      warn "Recording '$id' already exists!\n";
      print RED, "Do you want to modify the existing recording [y/n]? ", RESET;
	    my $choice = <STDIN>;
	    chomp $choice;
 	    unless ($choice eq "y"){
		     die "Nothing done!\n";
	    }          
      my $rec_id = $self->{recording}->{$value->id()}->id();
      # Remove all recording subjects from the database
      my $subj_table = $somsds_cfg->val('somsds', 'subj_csv');
      $subj_table =~ s/\..*$//;
      my $query = "DELETE FROM $subj_table WHERE recording='$rec_id'";
      $self->{_dbh}->do($query);             
    }      

		# Modify the root folder of the recording
		$value->root_path(catdir($self->{rec_path}, $value->id()));
		
		# Insert the recording into the SOMSDS object
		$self->{recording}->{$value->id()} = $value;

		# Generate the directory tree
		$self->{recording}->{$value->id()}->make_folders();

		# Copy the settings file and link the recording to it
		my $fname = basename($value->{settings_file});
		my $new_file = catdir($value->root_path(), 'doc', $fname);
                # We need to unprotect the existing file, in order to be able to overwrite it
		if (-e $new_file){
			my $base_dir = catdir($value->root_path(), 'doc');
			system("chattr -a -i $new_file");
			system("chattr -a $base_dir");
			chmod 0755, $new_file;
		}
                copy($value->{settings_file}, $new_file);
		$self->{recording}->{$value->id()}->settings_file($new_file);
		
		$self->{recording}->{$value->id()}->protect();

    # Insert the recording to the SOMSDS object and update the database
    $self->{recording}->{$value->id()} = $value;  
    $self->{recording}->{$value->id()}->save($self); 
           
  }
  return $self->{recording};
}

################################################################ PRIVATE METHODS


# Helper function for update_file_list
sub _update_file {
  my ($self, $rec, $file_descr_regex, $formats, $tests, $links) = 
    (shift, shift, shift, shift, shift, shift);

  return unless ($_ =~ /$file_descr_regex/);

  my $fh = Tie::Handle::CSV->new(csv_parser     => Text::CSV_XS->new(),
                                   file         => $File::Find::name,
                                   header       => 1,
                                   key_case     => 'lower');

  # Read the descriptor file line by line
  my $counter       = 1;
  my $link_counter  = 0;
  my $inserted;

  CSVLINE: while (my $line = <$fh>){
    $counter++;
    $inserted = undef;
    my $listed_filename;
    # Check that the file name is valid and that the file actually exists
    unless ($listed_filename = abs_path $line->{'id'}){
      print RED, 
        "Warning: Invalid filename in line $counter of descriptor file:
                  $File::Find::name
        ", RESET, "\n\n";
			next CSVLINE;
    }

    unless (-e $listed_filename){
      print RED,  
        "Warning: I could not find file $listed_filename
                  File is listed in line $counter of descriptor file:
                  $File::Find::name
        ", RESET,"\n\n";			
			next CSVLINE;
    }

    # Make the file name relative to the recording root
    my $abs_listed_filename = $listed_filename;
    my $root = $self->{recording}->{$rec}->root_path();
    $listed_filename =~ s&$root(\\|/)&&;
 
    # Check wether the file description looks OK
    for my $field (keys %{$tests}){
      next unless $line->{$field};
      unless (any {$_ eq $line->{$field}} @{$tests->{$field}}){
        croak 
        "Error: Invalid $field '$line->{$field}' of file:\n".
        "$listed_filename\n". 
        "Valid values of field $field for this recording are:\n".
        join(', ', @{$tests->{$field}})."\n".
        "Did you forget to update the recording settings file?\n\n";
      }
    }

    for my $field (keys %{$line}){
      next unless (any {$_ eq $field} qw(subject modality device technique condition));
      next unless ($line->{$field});
      unless (any {$_ eq $field} keys %{$tests}){
        die
        "Error: Invalid $field '$line->{$field}' of file:\n".
        "$listed_filename\n". 
        "Field $field is not even mentioned in the recordings settings file\n".
        "Did you forget to update the recording settings file?\n\n";
      }
    }
    
    # Check that the file has the right extension
    $listed_filename =~ /(.[^.]*)$/;
	if ($formats->{"$line->{modality}"} &&
    none {uc($1) eq uc($_)} @{$formats->{"$line->{modality}"}}){
	  print RED,"Warning: Invalid extension $1 for modality $line->{modality}\n".
	  "         Allowed extensions are: @{$formats->{$line->{modality}}}\n",
      "         Ignoring $listed_filename", RESET,"\n\n";				
	  next CSVLINE;	
	} 

    my $db_rel_listed_filename = 
      File::Spec->abs2rel(  $abs_listed_filename, 
                            catdir( $self->{root_path},                                     
                                    $self->{db_folder}));

    my $file=File->new($db_rel_listed_filename, $line);
    $file->recording($rec);    

    # Create a symbolic link to this file (relative to the location of raw)
    my $path_pattern  = $somsds_cfg->val('Recording', 'path_pattern');
    my $link_name     = $file->link_name();
    my $file_name     = $File::Find::name;
    if (exists $links->{$link_name}){
      carp 
        RED, "Line $links->{$link_name}->{lineno} of descriptor file:\n".
        "$links->{$link_name}->{file}\n".
		"which describes:\n".
		"$links->{$link_name}->{item}\n".
        "seems to duplicate line $counter of file:\n".
        "$file_name\n".
		"which describes file:\n".
		"$db_rel_listed_filename\n".
        "Both lines generate the link:\n $link_name\n".
        "It is recommended to remove or edit one of those two lines and run ".
        "'somsds_rec_update $rec'\n".
        "Ignoring $listed_filename", RESET, "\n";
    }
    $links->{$link_name} = {file    => $file_name,
                            item    => $db_rel_listed_filename,
                            lineno  => $counter};

    $link_name =~ m|^(.+)/[^/]+$|;   
    if (-e $link_name){
      unlink $link_name;
    }
    symlink $abs_listed_filename, $link_name;
    unless (-e $link_name){
      croak "I could not create the link $link_name\n";
    }
    print "$link_name \n-->> $abs_listed_filename\n\n"; 

    # Add the file to the corresponding recording
    my $file_obj = File->new($abs_listed_filename, $line);
    foreach (qw(sex age group)){
      my $field_value = $self->{recording}->{$rec}->{settings}
                        ->val("subject $line->{subject}", $_);
      my $cmd = '$file_obj->'.$_.'($field_value)';
      eval($cmd);
    }    
    $file_obj->recording($rec);
    $self->{recording}->{$rec}->file($file_obj);
    $link_counter++;    
   
  } # end of CSV line iterator
  print "Created $link_counter symbolic links\n";
  $self->{recording}->{$rec}->save($self);
}


#####################


# Loads info about the data structure from the database
sub _load {
  my $self = shift;  
  my $separator = $somsds_cfg->val('somsds', 'separator');
  my $quotes    = $somsds_cfg->val('somsds', 'quotes');
  my $db_folder = catdir($self->{root_path}, $self->{db_folder});
  my $csv_tables= $self->_db_tables();
  $self->{_dbh} = DBI->connect("dbi:CSV:", undef, undef, {
		f_dir 			    => $db_folder, 
		f_ext 			    => ".csv/r",
		csv_eol 		    => "\n", 
		csv_sep_char 	    => "$separator", 
		csv_quote_char   	=> "$quotes", 
		csv_tables 		  => $csv_tables,
		RaiseError 		  => 1,
		PrintError 		  => 1
		}) or croak $DBI::errstr;
  $self->_load_rec();
}



#####################


# Generates the directory trees for a project
sub make_proj_folders {
  my ($self, $proj_id, $users) = (shift, shift, shift);
  my @users = @$users;
  my $proj_folder = catdir($self->{root_path}, $self->{proj_folder}, $proj_id);
	my $proj_group = $proj_id;
  $proj_group =~ s/[-]//g;   

	my $cmd;
  # Create a new group
  unless ($^O eq 'darwin'){
    $cmd = '/usr/sbin/groupadd '.$proj_group;
    print $cmd,"\n";
    `$cmd`;
  }
  
 
  # Add the project members to the group
  unless ($^O eq 'darwin'){
    foreach (@users){
      $cmd = "/usr/sbin/usermod -a -G $proj_group $_";
      print $cmd,"\n";
      `$cmd`;
    }
  }
  
  my $path = $somsds_cfg->val('project', 'folders');
  my @paths = split("\n", $path);
  foreach (@paths){
    my $options   = {mode => 0775, verbose => 1};
    my $new_path  = catdir($proj_folder, split(/\s+/, $_));    
    make_path $new_path, $options;            
  }  
  # change the ownwerships
  if ($^O eq 'darwin'){
  	$cmd = "chown -R $users[0] $proj_folder";
  } else {
    $cmd = "chown -R $users[0]:$proj_group $proj_folder";
  }
  print $cmd,"\n";
  `$cmd`;
  $cmd = "chmod -R 0775 $proj_folder\n";
  print $cmd; 
  `$cmd`;       
}  

#####################

# Lists database tables (to be used by the DBI constructor)
sub _db_tables {
  my $self = shift;
  my $db_folder = catdir($self->{root_path}, $self->{db_folder});
	opendir(DBFOLDER_H, $db_folder);
	my @file = grep(/\.csv$/, readdir(DBFOLDER_H));
	closedir(DBFOLDER_H);
	my %csv_tables;
	foreach (@file){
	  s/\.csv//;
		$csv_tables{$_} = {file => $_.".csv"};
	}
  \%csv_tables;
}


#####################


# Generates empty database tables with proper headers
sub _make_csv_tables{
  my $self = shift;
  foreach (qw(rec_csv files_csv subj_csv)){ 
    my $csv_file = catfile( $self->{db_path}, $self->{$_});  
    if (!(-e $csv_file)){ 
      open (CSVFILE, '>'.$csv_file);
      print CSVFILE _header($_),"\n";
      close(CSVFILE);
    }
	  chmod (0777, $csv_file);
  }  
}


#####################


# Loads recordings' info from the database
sub _load_rec {

  my $self = shift;
  my $table = $somsds_cfg->val('somsds', 'rec_csv');
  my $rec_folder = $somsds_cfg->val('somsds', 'rec_folder');
  my $db_folder = $somsds_cfg->val('somsds', 'db_folder');
  my $root_path = $somsds_cfg->val('somsds', 'root_path');
  my $base_path = catdir($root_path, $db_folder);
  my $table_path = catdir($base_path, $table);

  return unless (-e $table_path);
  $table =~ s/\..*$//;
  my $query = "SELECT * FROM $table";
  my $sth = $self->sql($query);
  # Load each recording (a row of the recordings.csv table)
  while (my $row = $sth->fetchrow_hashref){
 
	my $settings_file = $row->{settings};
	unless (-e $settings_file){
    # Fix the mount mount
	  my $rec_id = $row->{id};
	  $settings_file =~ s/^.+$rec_folder.$rec_id.(.+)/$1/;
      $settings_file = catfile($root_path, $rec_folder, $rec_id, $settings_file);	  	  
	} 
	my $rec = Recording->new($settings_file);
    $rec->archived($row->{archived});

    $self->{recording}->{$rec->id()}=$rec;
    #IMPORTANT: Note that the files of the a given recording are not loaded!!!
  }

}


#####################


sub DESTROY {

}



1;
__END__

=head1 SOMSDS

SOMSDS - Perl module for maintaining somerenserver's standard data structure

=head1 SYNOPSIS
  
  # #################################
  # Direct use from the command line:
  # #################################

  # Creating a new SOMSDS structure
  somsds_new 

  # Inserting/removing a recording from the database
  somsds_new_rec myrec 
  somsds_remove_rec myrec 

  # Creating descriptor files for a directory tree containing data files
  somsds_descriptor mydir 

  # Importing a directory tree that contains data files
  somsds_import_rec myrec mydir

  # Refreshing the database tables of a given recording
  somsds_update_rec myrec

  # Pruning empty directories from a recording
  somsds_prune_rec myrec

  # Archiving/Unarchiving a recording
  somsds_archive myrec
  somsds_unarchive myrec

  # Protecing/Unprotecting a recording
  somsds_protect myrec
  somsds_unprotect myrec

  # Performing a database query
  somsds_query myrec "SELECT * FROM files WHERE modality='smri'"

  # #################################
  # Use as a module
  # #################################  
  
  Use SOMSDS;
  
  # Initialize
  $ds = SOMSDS->new();
  
  # Add a recording to the system
  $rec = SOMSDS::Recording->new('myrec');  
  $rec->subject(Subject->new('0001','0002');
  $rec->modality(Modality->new('eeg','meg','smri'));
  $rec->condition(Condition->new('rs','task'));
  $ds->recording($rec);  

  # Remove a recording
  $ds->remove_recording('myrec');

  # Generate descriptors
  SOMSDS::descriptors('/directory/with/data/files');

  # Import a directory with data files into a recording
  $ds->import_dir('myrec', '/dir/with/data/');

  # Archive/unarchive a recording
  $ds->archive_rec('myrec');
  $ds->unarchive_rec('myrec');

  # Protecting/unprotecting a recording
  $ds->protect_rec('myrec');
  $ds->unprotect_rec('myrec');

  # Performing a SQL query
  $ds->sql("SELECT * FROM files WHERE (sex='M') AND (recording='myrec')")
 

=head1 DESCRIPTION

The SOMSDS module is a collection of scripts intented to facilitate data 
sharing among the members of the Sleep&Cognition team of the Netherlands 
Institute for Neuroscience. 

The standard location of the installed scripts is: 

/usr/local/lib/perl5/site_perl/5.14.1

The location of the development scripts and the HTML documentation is:

/data/toolbox/somsds

The following symbolic links are stored in /usr/local/bin:

somsds_new   
         
somsds_new_rec

somds_remove_rec      

somds_descriptor      

somsds_import_rec     

somsds_update_rec     

somsds_prune_rec      

somsds_archive_rec    

somsds_unarchive_rec  

somsds_protect_rec

somsds_unprotect_rec

somsds_sql            

=head1 AUTHOR

German Gomez-Herrero, E<lt>g.gomez@nin.knaw.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by German Gomez-Herrero

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
