#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Generates symbolic links to a recording
# Documentation: utilities.txt

use Config::IniFiles;
use Getopt::Long;
use Cwd qw(abs_path cwd);
use File::Spec::Functions;
use List::MoreUtils qw(any);
use File::Path qw(make_path);
use File::Copy;
use SOMSDS;
use SOMSDS::File;

use strict;
use warnings;

sub subject_ids($$);

my $help;
my $orig;
my $ini_file = '/etc/SOMSDS.ini';
my ($vol, $dir, $file) = File::Spec->splitpath($0);

if (-e abs_path(catfile($dir,'SOMSDS.ini'))){
  $ini_file = abs_path(catfile($dir,'SOMSDS.ini'));  
} 

my $pipe;
my $linknames;
my $folder;
my @subjects_in;
my @sexes;
my $minage;
my $maxage;
my @groups;
my @modalities;
my @conditions;
my $condition_regex;
my $file_regex;
my @devices;
my @techniques;
my @sessions;
my @meta;
my @file_ext;
my $fasttb = '^.+fasttb.*\.mat$';
my $giotb = '^.+(eeg_scores.*\.mat|eeg_sleep_scores.*\.mat|giotb\.mat)$';

my $root_path;

GetOptions( "pipe"                  => \$pipe,
            "conf=s"                => \$ini_file,
            "linknames"             => \$linknames, 
            "help"                  => \$help, 
            "orig"                  => \$orig,
            "folder=s"              => \$folder,
            "subjects|subject=s"    => \@subjects_in,
            "sexes|sex=s"           => \@sexes,
            "minage=s"              => \$minage,
            "maxage=s"              => \$maxage, 
            "groups|group=s"        => \@groups,
            "modalities|modality=s" => \@modalities,
            "conditions|condition=s"=> \@conditions,
            "cond_regex=s"          => \$condition_regex, 
            "file_regex=s"          => \$file_regex,
            "devices|device=s"      => \@devices,
            "techniques|technique=s"=> \@techniques,
            "sessions|session=s"    => \@sessions,
            "meta|metas=s"          => \@meta,
            "file_ext|fext=s"       => \@file_ext,
            "fasttb"                => \$fasttb,	
            "root_path=s"           => \$root_path            
          );
			
my $rec = shift;

if ($help || !$rec){
  print "
  
  Usage: 
  
  somsds_link2rec recid [--options]
  
  Where:
  
  recid          A recording ID
  
  
  
  ## COMMON OPTIONS
  
  --folder      full path where the symbolic links will be stored. By default, 
                the links will be stored in a folder called 'recid', under the 
                current working directory.
  
  --orig        keep the original folder structure, i.e. do not simply place all
                the links under 'folder' but do create also the subfolders 
                structure as can be found in /data/recordings/[recid]/
  
  
  ## LESS COMMON OPTIONS
  
  --subject     comma separated list of subject IDs, e.g. 1,2..5,8
  
  --sex         comma separated list of sexes, e.g. M,F
  
  --minage      minimum age of the subjects to be processes
  
  --maxage      maximum age
  
  --group       comma separated list of groups, e.g. controls,AD
  
  --modality    comma separated list of modalities, e.g. eeg,smri
  
  --condition   comma separated list of conditions, e.g. rs-eo,rs-ec,gonogo

  --cond_regex  a regular expression matching the relevant conditions. For
                example a cond_regex '^rs' will match all condition IDs that 
                start with the string 'rs'    

  --file_regex  a regular expression matching the relevant files          

  --file_ext    a comma separated list of file extensions 
  
  --device      comma separated list of devices, e.g. egi256
  
  --technique   comma separated list of techniques, e.g. t1,dist,prox
  
  --session     comma separated list of session IDs, e.g. 1,4

  --meta        comma separated list of meta IDs, e.g. tsss,raw
  
  --conf        optional configuration file for the generation of the links

  --fasttb      regular expression that matches fast toolbox files

  --giotb       regular expression that matches Gio's toolbox sleep scores files

  --linknames   if this flag is provided, will no create links but will just
                print to the standard output the link names
  
  --help        displays this help\n";
  die "\n";
}

unless ($folder){
  $folder = catdir(cwd(), $rec);
}

$folder = File::Spec->rel2abs($folder);

# Merge multiple --condition/--field invocations
my $subjects  = join(',', @subjects_in);
@sexes        = split(/,/, join(',', @sexes));
@groups       = split(/,/, join(',', @groups));
@modalities   = split(/,/, join(',', @modalities));
@conditions   = split(/,/, join(',', @conditions));
@devices      = split(/,/, join(',', @devices));
@techniques   = split(/,/, join(',', @techniques));
@sessions     = split(/,/, join(',', @sessions));
@meta         = split(/,/, join(',', @meta));
@file_ext     = split(/,/, join(',', @file_ext));

# Generate subject ids of the form 000x
my @subjects = ();
if ($subjects){
  my @tmp_subjects = split(/\s*,\s*/, $subjects); 
  foreach (@tmp_subjects){    
    if ($_ =~ m/(\d+)\.\.(\d+)/){      
      my @this_subjects = subject_ids($1, $2);  
      @subjects = (@subjects, @this_subjects);      
    }elsif ($_ =~ m/^\d+$/){
      push @subjects, subject_ids($_, $_);  
    }else{
      push @subjects, $_;    
    }    
  }
}

if (@subjects){
  $subjects  = '\''.join('\',\'', @subjects).'\'';
}

my $ds  = SOMSDS->new($root_path);

my $query = "SELECT * FROM files WHERE recording='$rec'";
if ($subjects){
  $query = $query." AND subject IN ($subjects)";
}

my $sth = $ds->sql($query);	

# Read configuration file
my $conf = new Config::IniFiles(-file => $ini_file);

# Select the relevant files
my %files;

while (my $row = $sth->fetchrow_hashref){

  my $selected = 1;
  if (@sexes){
    $selected = $selected & any {$_ eq $row->{sex}} @sexes;
  }  
  if (@groups){
    $selected = $selected & any {$_ eq $row->{group}} @groups;
  }  
  if (@modalities){
    $selected = $selected & any {$_ eq $row->{modality}} @modalities;
  }  
  if (@conditions){
    $selected = $selected & any {$_ eq $row->{condition}} @conditions;
  }  
  if ($condition_regex){
    my $tmp = $row->{condition};
    $selected = $selected & $tmp =~ m/$condition_regex/ig;
  } 
     

  if (@devices){
    $selected = $selected & any {$_ eq $row->{device}} @devices;
  }  
  if (@techniques){
    $selected = $selected & any {$_ eq $row->{technique}} @techniques;
  }  
  if (@sessions){
    $selected = $selected & any {$_ eq $row->{session}} @sessions;
  }  
  if (@meta){
    $selected = $selected & any {$_ eq $row->{meta}} @meta;
  }  
  if (@file_ext){
	my $tmp = $row->{id};
	$tmp =~ s%^.+(\.[^./]+)$%$1%;
	$selected = $selected & any {$_ eq $tmp} @file_ext;
  }

  my $lname;
  my $filename;
  my $link_name  = $conf->val('link', 'name');
  my $link_path  = $conf->val('link', 'path');
  my $sep        = $conf->val('link', 'field_sep');
  my $space      = $conf->val('link', 'space_char');

  my $file       = File->new($row->{id}, $row);
  $lname         = $file->link_name($link_name, $link_path, $sep, $space);
  $filename      = $file->link_name();

  if ($file_regex){
    $selected = $selected & $filename =~ m/$file_regex/ig;
  }

  if ($selected){
   
    
    

    if ($orig){
      my $stem       = catdir($ds->{root_path}, $ds->{rec_folder}, $rec);
	  $stem          =~ s%\\%/%g;	  
	  $lname         =~ s%\\%/%g;	  
      $lname         =~ s%^$stem.%%;	  
    }else{
	  (my $tmp1, my $tmp2, $lname) = File::Spec->splitpath($lname);	  
      #$lname         =~ s%.+/([^\\/]+)$%$1%;
    }
    
    my $is_fasttb = ($filename =~ m/$fasttb/ig);
    my $is_giotb  = ($filename =~ m/$giotb/ig);
    $lname         = catfile($folder, $lname);	

    $files{$lname} = {filename  => $filename, 
                      is_fasttb => $is_fasttb,
                      is_giotb  => $is_giotb};

  }
} 

unless ($linknames || -e $folder){
  mkdir $folder;
}


# Create the links
while (my ($lname,$value) = each(%files)){

  my ($volume, $path) = File::Spec->splitpath($lname);
  $path = catdir($volume, $path);
  #$path =~ s%^(.+)/[^/]+$%$1%;
  
  
  if ($linknames){
    print "$lname\n";
  } else {
    make_path $path;
    if ($value->{is_fasttb}){
      # If it is a fast file we must copy it instead of linking to it
      copy($value->{filename}, $lname);    
      print "$lname \n-->> $value->{filename}\n\n";
      print "Fixing $lname...";
      File::fix_fasttb($lname);
      print "[done]\n\n";
    } elsif ($value->{is_giotb}){
      # Copy the file and fix it
      copy($value->{filename}, $lname);    
      print "$lname \n-->> $value->{filename}\n\n";
      print "Fixing $lname...";
      File::fix_giotb($lname, $value->{filename});
      print "[done]\n\n";
    } else {
        if ($pipe){
            my $success = symlink $value->{filename}, $lname;
            print "$lname\n" if $success;
        } else {
            symlink $value->{filename}, $lname || 
            die "Failed to produce link:\n".
              "$lname -->> $value->{filename}\n";	 
            print "$lname \n-->> $value->{filename}\n\n";          
        }
    }
  }
     
}

sub subject_ids($$) {
  my ($first, $last) = (shift, shift);
  my @ids = ();
  for (my $i=$first; $i<=$last; ++$i){
    push @ids, "0"x(4-length("$i"))."$i";    
  }
  @ids;
}
