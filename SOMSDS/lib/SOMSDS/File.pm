#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: File class
# Documentation: modules.txt


package File;

use SOMSDS::File;
use Carp;
use Cwd 'abs_path';
use Config::IniFiles;
use File::Spec::Functions;
use File::Basename;
use File::Find;
use Time::Format qw(%time);
use File::Copy "cp";

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

our $AUTOLOAD;

# Read SOMSDS configuration options
my ($vol, $dir, $file) = File::Spec->splitpath($0);
my $somsds_file;
if ($vol){
  $somsds_file = abs_path catfile($vol, $dir,'SOMSDS.ini');
} else {
  $somsds_file = abs_path catfile($dir,'SOMSDS.ini');
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
  my $class = shift;

  my %fields = (
    id          => undef,
    root_path   => undef,
    recording   => undef,
    subject     => undef,
    sex         => undef,
    age         => undef,
    group       => undef,
    modality    => undef,
    device      => undef,
    technique   => undef,
    condition   => undef,
    session     => undef,
    block       => undef,
    meta        => undef
  );

  my $self = {
    _permitted => \%fields,
    %fields,
  };

  $self->{id} = shift;
  my $fields = shift;
  if ($fields){
    for (qw(recording subject modality device technique condition session block meta))
    {
      if ($fields->{$_}) {$self->{$_} = $fields->{$_}};
    }
  }

  bless $self, $class;
  return $self;
}


###################

# Generates a text file with a description of each file to which a link will be
# generated
sub descriptors {
  my $root = shift;
  my $descr_subj;

  while (my $ini_file = shift){
    my $ini = new Config::IniFiles(-file => $ini_file) ||
      croak "I can't access the configuration file $ini_file:\n";

    my $iniCopy = catfile($root, basename($ini_file));
    if (-e $iniCopy){
        system("chattr -a $root");
        system("chattr -a $iniCopy");
        system("chattr -i $iniCopy");
        unlink($iniCopy);
    }


    cp($ini_file, $iniCopy);
    system("chattr +a $root");

    my $descr_file		= $somsds_cfg->val('descriptor', 'file');

    # Strip quotes from regular expressions
    my %regexp;
  	foreach (qw(file_exclude_id file_id subject_id modality_id device_id technique_id
                condition_id session_id block_id
                  meta_id)){
			if ($ini->exists($_,'regexp')){
	    	$regexp{$_} = $ini->val($_,'regexp');
			} else {
				$regexp{$_} = $somsds_cfg->val($_,'regexp');
			}
      next unless $regexp{$_};
  		$regexp{$_} =~ s/^"(.*)"$/$1/;
  	}

    # Generate an empty file descriptor file
    my $name = fileparse($ini_file, qr/\.[^.]*/);
    $name =~ s/[._]/-/g;

    $descr_file =~ s/(\.[^\.]+)//;
    $descr_file = catfile($root, $descr_file."_$name$1");
    open (CSVFILE, '>'.$descr_file) ||
      croak "I could not open $descr_file: $!\n";
     print CSVFILE
      qq["id","subject","modality","device","technique","condition","session","block","meta"],
           "\n";
     #print "Creating file descriptions: $descr_file..."; $|++;
    print "$descr_file\n";
    # Search for files that need to be described within the directory tree
    find(
    	sub
    	{
    		_describe_file(\%regexp, $ini, $root);
    	},
    	$root);
    close(CSVFILE);
    chmod 0755, $descr_file or die "Coudn't chmod $descr_file: $!";
    #print "[done]\n";
  }

}


##########
# Fixes FAST toolbox files

sub fix_fasttb {
    my $pathname = shift;
    my $dir  = dirname($pathname);
    my $file = basename($pathname);
    my $dat_file = $file;
    $dat_file =~ s%(.mat)$%.dat%;
    my $dat_pathname = catdir($dir, $dat_file);
    my $spm8_path = $somsds_cfg->val('dependencies', 'spm8');
    my $cmd = 'matlab -nosplash -nodisplay -r "try, cd(\''.$dir.'\');'.
      'addpath(genpath(\''.$spm8_path.'\'));'.
      'load(\''.$file.'\');'.
      'D.path=\''.$dir.'\';'.
      'D.fname=\''.$file.'\';'.
      'D.data.fnamedat=\''.$dat_file.'\';'.
      'D.data.y.fname=\''.$dat_pathname.'\';'.
      'save(\''.$file.'\',\'D\');'.
      'exit;'.
      'catch, '.
      'exit;end"';
    `$cmd`;
    `stty echo`; # For some reason loading $files screws with the terminal echo
    #return;
}

##########
# Fixes sleep score files from Giovanni's toolbox

sub fix_giotb {
    my $pathname = shift;
    my $absPath  = abs_path(shift);
    my $dir      = dirname($absPath);
    my $thisDir  = dirname($pathname);
    my $thisFile = basename($pathname);
    my $cmd = 'matlab -nosplash -nodisplay -r "try, cd(\''.$thisDir.'\');'.
      'load(\''.$thisFile.'\');'.
      '[~, datasetName] = fileparts(info.dataset);'.
      '[~, infoName] = fileparts(info.infofile);'.
      'dirName=\''.$dir.'\';'.
      'info.dataset = [dirName filesep datasetName \'.mff\'];'.
      'info.infofile = \''.$pathname.'\';'.
      'save(\''.$thisFile.'\',\'info\');'.
      'exit;'.
      'catch, '.
      'exit;end"';
    `$cmd`;
    `stty echo`; # For some reason loading $files screws with the terminal echo
    #return;
}




################################################################# PUBLIC METHODS

# Generates symbolic link names using the file properties (subject, mod, etc..)
sub link_name {
  my $self          = shift;
  my $link_name     = shift || $somsds_cfg->val('link', 'name');
  my $path_pattern  = shift || $somsds_cfg->val('link', 'path');
  my $sep           = shift || $somsds_cfg->val('link', 'field_sep');
  my $space         = shift || $somsds_cfg->val('link', 'space_char');
  my $rec       = $self->{recording};
  my $subject   = $self->{subject};
  my $modality  = $self->{modality};
  my $technique = $self->{technique}  || '';
  my $device    = $self->{device}     || '';
  my $condition = $self->{condition}  || '';
  my $session   = $self->{session}    || '';
  my $block     = $self->{block}      || '';
  my $meta      = $self->{meta}       || '';
  $meta =~ s/[;.\s]/-/g;
  unless ($rec){
    die "No recording specified for file $self->{id}\n";
  }

  unless ($subject){
    die "No subject specified for file $self->{id}\n";
  }

  unless ($modality){
    die "No modality specified for file $self->{id}\n";
  }

  # Replace field separator characters that appear within a field
  # EXCEPT FOR THE META FIELD, WHICH CAN CONTAIN ANY CHARACTER
  for my $field ( \$subject, \$modality, \$condition, \$session, \$block,
            \$technique, \$device){

    $$field =~ s/$sep/$space/g;
    $$field =~ s/\s+/$space/g;
  }

  # Directory where the links will be located
  my $path      = $path_pattern;
  my @path      = split("\n", $path);
  $path         = $path[0];
  $path         =~ s/SUBJID/$subject/g;
  $path         =~ s/MODID/$modality/g;
  $path         =~ s/DEVID/$device/g;
  $path         =~ s/TECID/$technique/g;
  $path         =~ s/CONDID/$condition/g;
  $path         =~ s/SESSID/$session/g;
  $path         =~ s/BLKID/$block/g;
  $path         =~ s/META/$meta/g;
  $path         = catdir( $somsds_cfg->val('somsds', 'root_path'),
                          $somsds_cfg->val('somsds', 'rec_folder'),
                          $rec,
                          split(/\s+/,$path));
#print $somsds_cfg->val('somsds', 'root_path'),"\n";
#  $path = catdir($somsds_cfg->{root_path}, $somsds_cfg->{rec_folder}, $path);
  $link_name         =~ s/RECID/$rec/g;
  $link_name         =~ s/SUBJID/$subject/g;
  $link_name         =~ s/MODID/$modality/g;
  $link_name         =~ s/DEVID/$device/g;
  $link_name         =~ s/TECID/$technique/g;
  $link_name         =~ s/CONDID/$condition/g;
  $link_name         =~ s/SESSID/$session/g;
  $link_name         =~ s/BLKID/$block/g;
  $link_name         =~ s/META/$meta/g;
  $link_name         =~ s/(\s+)/$sep/g;
  $link_name         =~ s/($sep+)$//;

  # Attach the file extension to the link name
  my $file_ext;
  if ($self->{id} =~ m%.+\.([^./]+)\.gz$%){
    $file_ext = ".$1.gz";
  }else{
    $self->{id} =~ m%.+(\.[^/]+)$%;
    $file_ext = $1;
  }

  $link_name = catfile($path,$link_name.$file_ext);
}

###################

sub filename {
  my $self = shift;
  return abs_path catdir($self->{root_path}, $self->{id});
}


sub _class_autoload {
  my ($name, $force_type, $self, $value) = (shift, shift, shift, shift);
  my $type = ref($self) or croak "$self is not an object";
  $name =~ s/.*://;   # strip fully-qualified portion

  unless (exists $self->{_permitted}->{$name}) {
    croak "Can't access '$name' field in class $type";
  }

  if ($value) {
    unless (ref($value) eq $force_type) {
      croak "$self is not an object of class $force_type!"
    }
    $self->{$name} = $value;
    return $self;
  }
  return $self->{$name};
}

sub save {
  my ($self, $somsds_obj) = (shift, shift);
  my $files_table = $somsds_cfg->val('somsds', 'files_csv');
  $files_table =~ s/\..*$//;

  # We assume that all files from this recordings have been removed
  my $query = "INSERT INTO $files_table VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $file_id = $self->id();
  my $uname = getpwuid( $< );
  my @entry = ( $file_id,
                $uname,
                $time{'yyyy/mm/ddThh:mm:ss'},
                $self->{recording},
                $self->{subject},
                $self->{sex},
                $self->{age},
                $self->{group},
                $self->{modality},
                $self->{device},
                $self->{technique},
                $self->{condition},
                $self->{session},
                $self->{block},
								$self->{meta}
                );

#print join(',',@entry);die;
  $somsds_obj->sql($query, undef, @entry);

}


######################################################### PRIVATE HELPER METHODS


# Helper function for public static method descriptors()
sub _describe_file {
    my ($regexp, $ini, $root) = (shift, shift, shift);
    # Another parameter for valid file extensions within a modality!!!
    # If it is not a valid extension, skip
    my $file_regexp = $regexp->{file_id};
    my $file_exclude_regexp = $regexp->{file_exclude_id};
    my $fname = $File::Find::name;
    return if (-l $fname);
    $fname = File::Spec->abs2rel($fname, $root);

# Field separator and space character
my $field_sep = $somsds_cfg->val('link','field_sep');
my $space_char = $somsds_cfg->val('link','space_char');

return unless ($file_regexp && $fname =~ m&$file_regexp&);
return if ($file_exclude_regexp && $fname =~ m&$file_exclude_regexp&);
# Try to find out subject, mod, cond, sess, block and make an entry in the
# descriptor file

	print CSVFILE qq["$fname",];
	foreach (qw(subject_id modality_id device_id technique_id condition_id
              session_id block_id meta_id)){
		my $this_regexp = $regexp->{$_};

		my $new_value = $fname;

		if ($this_regexp) {
			eval('$new_value =~'."$this_regexp;");
			if ($new_value eq $fname){
				$new_value = '';
			}else{
                           if ($ini->val($_.'_map', $new_value)){
		           # Translate the value (_ means translate to empty)
                           if ($ini->val($_.'_map', $new_value) eq $field_sep){
                           $new_value = '';
                           } else {
			     $new_value = $ini->val($_.'_map', $new_value);
                           }
			   }
                           # Remove separator characters
                           #unless ($_ eq "meta_id"){
                           #$new_value =~ s/$field_sep/$space_char/g;
                           #}
	                }
	  }else{
	     undef $new_value;
	  }
	  if ($new_value) {
          $new_value =~ s/\s+/-/g;
          $new_value =~ s/_+/-/g;
			print CSVFILE qq["$new_value",];
		} else {
			print CSVFILE ",";
		};
	}

	print CSVFILE "\n";
}


#####################

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
