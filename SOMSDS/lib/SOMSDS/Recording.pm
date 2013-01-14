#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Recording class
# Documentation: modules.txt

package Recording;

use Carp;
use Cwd qw(abs_path cwd);
use List::MoreUtils qw(any);
use Config::IniFiles;
use File::Spec::Functions;
use File::Path qw(make_path);
use File::Find;
use Time::Format qw(%time);
use Fcntl ':mode';
use File::Basename;
use File::Copy::Recursive qw(dircopy);
use Linux::Ext2::FileAttributes;

#use 5.014001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.


our @EXPORT_OK = ( 'new' );

our @EXPORT = qw(
	new
);

our $VERSION = '0.01';

our $AUTOLOAD;


# Read SOMSDS configuration options
my ($vol, $dir, $file) = File::Spec->splitpath($0);
#print "$vol --- $dir --- $file\n"; die;
my $somsds_file;
if ($vol){
  $somsds_file        = abs_path catfile($vol, $dir, 'SOMSDS.ini'); 
} else {
  $somsds_file        = abs_path catfile($dir, 'SOMSDS.ini'); 
}

unless (-e $somsds_file){  
  $somsds_file = '/etc/SOMSDS.ini'; 
} 
unless (-e $somsds_file){
  croak "I could not find the configuration file $somsds_file\n";
}
my $somsds_cfg = new Config::IniFiles(-file => $somsds_file);


########################################################## PUBLIC STATIC METHODS


sub new {
  my $class         = shift;
  my $settings_file = shift;
  my $options       = shift;
  my %fields = (
    id          => undef,
    root_path   => undef,
    archived    => undef,   
    file        => {},
    subject     => {},  
    modality    => {},
    condition   => {},
    technique   => {},
    device      => {},
    session     => {},
    block       => {},
    settings       => undef,
    settings_file  => undef,
    meta        => {} 
  );
  my $self = {    
    _permitted      => \%fields,
    %fields,
  };    
  
  # Load recording settings 
  unless ($settings_file && -e $settings_file){
    die "I could not find the recording settings file $settings_file\n";
  }

  $self->{settings} = new Config::IniFiles(-file => $settings_file);
  
  $self->{settings_file} = $settings_file;
  my @recid = $self->{settings}->GroupMembers('recording');
  unless (@recid){
    croak "Recording ID is missing from file $settings_file\n";
  }
  
  if (scalar @recid > 1){
    croak "Found multiple recording IDs in $settings_file: ", @recid, "\n";
  }
  $self->{id} = shift @recid;
  $self->{id} =~ s/recording\s+//;
  
  # Read recording meta-information
  my $sec = 'recording '.$self->{id};
  foreach ($self->{settings}->Parameters($sec)){
    $self->{meta}->{$_} = $self->{settings}->val($sec, $_);
  }  

  # Load recording settings
  for my $group (qw(subject modality device technique device session block condition)){
    for my $group_member ($self->{settings}->GroupMembers($group)){

      if ((any {$_ eq $group} qw(modality device technique)) &&
                !$somsds_cfg->SectionExists("$group_member")){
        croak 
        "$group_member is not listed in $somsds_file\n".
        "Listed values of field ''$group'' are:\n".
        join(', ', $self->{settings}->GroupMembers($group));
      }
      my $group_member_name = $group_member;
      $group_member_name =~ s/$group\s+//;
      $self->{$group}->{$group_member_name} = {};
      for my $param ($self->{settings}->Parameters("$group_member")){     
        $self->{$group}->{$group_member_name}->{$param} = 
          $self->{settings}->val("$group_member", $param);
      }
    }
  }
  
  
  # There must be at least one modality and one subject
  for (qw(modality subject)){
    unless (keys %{$self->{$_}}){
      croak "At least one $_ must be specified in $settings_file\n";
    }
  }    
  
  bless $self, $class;

  # Create the folder structure  
  if (exists($options->{tmp}) && $options->{tmp}) {
	  $self->root_path(catdir(cwd(), $self->{id}));

  }else {
    # The root path of the recording
    $self->root_path(
                  catdir($somsds_cfg->val('somsds', 'root_path'),
                         $somsds_cfg->val('somsds', 'rec_folder'), 
                         $self->{id})
                );
  }
 
  # If there are multiple input ids
  if (@_){
    my @self = ($self);
    while (my $id = shift){
      my $new_rec = Recording->new($id);
      @self = push @self, $new_rec;
    }
    return @self;
  }  
  
  return $self;
}  


#################################


sub string_as_meta {
  my $str = shift;
  my %meta;
  my @str = split(/\s;\s/, $str);
  foreach (@str){
    my ($key, $value) = split(/\s:\s/, $_);
    $meta{$key}=$value;
  }
  \%meta;
}

#################################

# prints the meta attribute (to introduce it in a .csv table)
sub meta_as_string {
  my $meta = shift;
  my $out_str = '';
  while (my ($key, $value) = each %{$meta}){
    if ($value) {$out_str = $out_str."$key : $value ; ";}
  }
  $out_str;
}

#################################

# Imports data from a directory tree into a recording
sub import_dir {
  my ($self, $dir, $fuse)     = (shift, shift, shift);
  my $conf_file = shift;

  $dir =~ s&/$&&;

  my $conf = new Config::IniFiles(-file => $conf_file);

  my $inc_regex = $conf->val('include', 'regexp'); 
  my $exc_regex = $conf->val('exclude', 'regexp');	

  if ($fuse){
    # Copy $dir into recordings/$rec/
    dircopy($dir, $self->{root_path});
  } else {  
    if ($inc_regex) {$inc_regex =~ s/^"(.+)"$/$1/;}
    if ($exc_regex) {$exc_regex =~ s/^"(.+)"$/$1/;}

    my $base_import_dir = catdir( $self->{root_path}, 
                                  $somsds_cfg->val('somsds', 
                                  'import_folder'));

    $conf_file = fileparse($conf_file, qr/\.[^.]*/); 
    my $import_dir  = catdir($base_import_dir, 
                             $conf_file."_".$time{'yyyy-mm-dd_hh-mm-ss'});
    # Copy $dir into $rec/imported/$date/ 
    if (!$inc_regex && !$exc_regex){
      print "$dir\n--->>$import_dir\n";
      dircopy($dir, $import_dir); 
      finddepth(sub{rmdir}, $import_dir);     
    } else {
      my $count=0;    
      find(sub 
  	  {
  	if ($inc_regex) {return unless ($File::Find::name =~ m/$inc_regex/);}
        if ($exc_regex) {return if ($File::Find::name =~ m/$exc_regex/);}
        $count++;

        # Copy the file to the new location
        my $import_file = $File::Find::name;
        $import_file =~ s&$dir&$import_dir&;   
             
        print "$File::Find::name \n---> $import_file\n\n";$|++;
  
        if (-d $File::Find::name){
          make_path $import_file
        }else{
          $import_file =~ m%(.+)/[^/]+$%;
          if ($1) {make_path $1;}  
            `cp $File::Find::name $import_file`;# || die "$!";
        }    
   
        chmod (0755, $import_file);
  	  },
      $dir);
      print "$count files were copied int $import_dir\n";             
    } # endif
    # Make the import dir inmutable
    finddepth(sub
        {
           system("chattr +i $File::Find::name");    
        }, $import_dir); 
    print "made inmutable $import_dir'\n";
  }


}


################################################################# PUBLIC METHODS


sub root_path {
  my ($self, $path) = (shift, shift);
  if ($path) {    
    $self->{root_path} = $path;
    return $self;
  }
  return $self->{root_path};
}

#################################

sub protect {
  #}
  my $self = shift;
  my $dir = $self->root_path();
  find(sub 
  	{
		return if ($File::Find::name =~ m%raw/{0,1}[^/]*$%);
		return if ($File::Find::name =~ m%$dir/files_[^/]+.csv$%);
  		chmod 0555, $File::Find::name;
		my $cmd = "chattr -i \"$File::Find::name\"";
		print "$cmd\n";	
		system($cmd);
		$cmd = "chattr +a \"$File::Find::name\"";
		print "$cmd\n";
		system($cmd);
		unless (-d $File::Find::name){
			my $cmd = "chattr +i \"$File::Find::name\"";
			print "$cmd\n";
			system($cmd);
		}
  	},
    $dir
  );
}


#################################

sub unprotect {
  my $self = shift;
  my $dir = $self->root_path();
  find(sub 
  	{
 		return if ($File::Find::name =~ m%raw/{0,1}[^/]*$%);
		chmod 0755, $File::Find::name;
		my $cmd = "chattr -a \"$File::Find::name\"";
		print "$cmd\n";
		system($cmd);
		unless (-d $File::Find::name){
			my $cmd = "chattr -i \"$File::Find::name\"";
			print "$cmd\n";
			system($cmd);
		}

  	},
   $dir
  );
}




#################################


sub make_folders {
  my $self = shift;
  my $responsible = getpwuid( $< );
  if (exists $self->{meta}->{responsible}){
    $responsible = $self->{meta}->{responsible};
    $responsible = getpwnam($responsible);
  }  

  for (qw(subject modality condition device session block)){
		unless (keys %{$self->{$_}}){
			$self->{$_}->{''} = undef;
		}
	}
  my $path;
  for my $subjid (keys %{$self->{subject}}){
    for my $modid (keys %{$self->{modality}}){
      for my $condid (keys %{$self->{condition}}){
        for my $devid (keys %{$self->{device}}){
          for my $sessid (keys %{$self->{session}}){
            for my $blkid (keys %{$self->{block}}){              
              $path         = $somsds_cfg->val('recording','folders');
              $path         =~ s/SUBJID/$subjid/g;
              $path         =~ s/MODID/$modid/g;
              $path         =~ s/CONDID/$condid/g;
              $path         =~ s/CONDID/$devid/g;              
              $path         =~ s/SESSID/$sessid/g;
              $path         =~ s/BLKID/$blkid/g;
              my @paths = split("\n", $path);

              foreach (@paths){
                my $options   = { mode => 0755, verbose => 1, 
                                  owner => $responsible};
                my $new_path  = catdir($self->root_path(), split(/\s+/, $_));                      
				unless (-e $new_path){
	              	make_path $new_path, $options;  
					#print "mkdir $new_path\n";                                             
				}
                
								
              }
            }
          }
        }
      }
    }
  }

  chown $responsible, -1, $self->root_path();
}


#################################

sub prune {
  my $self 	= shift;
	my $doc 	= shift; # Remove doc directories?
  my $dir_tree = $self->{root_path};
  print "Pruning directory tree: ",$dir_tree, " ...";
	if ($doc){
	  finddepth(sub{rmdir;}, $dir_tree);
	} else {
    finddepth(sub{
                  unless (m%(doc/|raw/)%){     
                  rmdir;
                  }
                 }, $dir_tree);
	}
  print "[done]\n";
}

#################################

sub clear_links {
  my $self = shift;
  find(sub
    {
      if ($File::Find::name =~ m|import/|) {return;}
      if ($File::Find::name =~ m%^.+/raw/.+\..+$%){
        unlink $File::Find::name;
        print "unlink $File::Find::name\n";
      }
    }, 
    catdir($self->{root_path}, 'subjects'));
}

#################################

sub save {  
  my ($self, $somsds_obj) = (shift, shift);
  my $rec_table = $somsds_obj->{'rec_csv'};
  $rec_table =~ s/\..*$//;
  my $files_table = $somsds_obj->{'files_csv'};;
  $files_table =~ s/\..*$//;

  # Remove the recording from the table if it is already there
  my $rec_id = $self->{id};
  my $query = "DELETE FROM $rec_table WHERE id='$rec_id'";
  $somsds_obj->sql($query);
  # Insert the recording in the recordings table
  $query = "INSERT INTO $rec_table VALUES (?,?,?,?,?,?)";
  my $uname = getpwuid( $< );
  my @entry = ( $rec_id,
                $uname, 
                $time{'yyyy/mm/ddThh:mm:ss'},
                $self->{archived},
                $self->{settings_file},
                meta_as_string($self->{meta}),
              );
    $somsds_obj->sql($query, undef, @entry);        

    # Insert files
    my $counter=0;
    my $num_files = keys %{$self->{file}};

    my $num_files_by100 = POSIX::ceil($num_files/100);    
    
    # Remove all files from this recording
    $query = "DELETE FROM $files_table WHERE recording='$rec_id'";
    $somsds_obj->sql($query); 
    while (my ($file_id, $file_obj) = each %{$self->file()}){
      $file_obj->save($somsds_obj);
      $counter++;
      unless ($counter % $num_files_by100 ) {
        my $pctg = POSIX::ceil(100*$counter/$num_files);
          print "Inserting files of recording '$rec_id' to the DB...$pctg%\r";
        $|++;  
      }      
    }
    print "\n";
}




#################################


sub file {
  _class_autoload('file', 'File', @_);
}

sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self) or 
    croak "$self is not an object\n";
    
  my $name = $AUTOLOAD;
  $name =~ s/.*://;
  unless (exists $self->{_permitted}->{$name}){
    croak "Can't access $name field in class $type\n";
  }
  
  if (@_){
    return $self->{$name} = shift;
  } else {
    return $self->{$name};
  }
}


sub _class_autoload {
  my ($name, $force_type, $self) = (shift, shift, shift);
  my $type = ref($self) or croak "$self is not an object";
  $name =~ s/.*://;   # strip fully-qualified portion

  unless (exists $self->{_permitted}->{$name}) {
    croak "Can't access '$name' field in class $type";
  }  

  OBJECT: while (my $value = shift) {
    if (ref($value) eq $force_type) {
      my $id = $value->id() || next OBJECT;
      $self->{$name}->{$id} = $value;      
    } else {
      croak "$self is not an object of class $force_type!"    
    }    
  }

  return $self->{$name};
}

#################################

sub DESTROY {

}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SOMSDS - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SOMSDS;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SOMSDS, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Germán, E<lt>german.gomezherrero@kasku.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by German Gomez-Herrero

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
