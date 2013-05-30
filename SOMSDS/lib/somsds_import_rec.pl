#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Imports data
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;
use File::Spec::Functions;
use Cwd 'abs_path';

my $root_path;
my $descr_regex;
my $fuse;
my $conf_file = '/etc/SOMSDS.ini';
my $help;

GetOptions( "descriptor=s" => \$descr_regex,	   
            "root=s"       => \$root_path,   
            "fuse"         => \$fuse,
            "conf=s"       => \$conf_file,  
            "help"         => \$help);
			
my ($rec, $dir) = (shift,shift);

if ($help || !$rec || !$dir){
  print "

* Imports (copies) data into a recording directory tree
  
  Usage: 

  somsds_import_rec recid dirtree

  Where:

  recid 	  A recording ID

  dirtree         The directory tree where the data can be found


  # OPTIONS
	

  --fuse          Attempt to fuse the imported data with the destination
                  data structure. Use this option only if you are importing data
                  that follows stricly the SOMSDS guidelines

  --conf          Configuration file with a [include] and/or [exclude] sections
                  that specify which files within the directory tree are to be
                  copied   
  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}


my $ds = SOMSDS->new($root_path);
unless ($ds){
  die "Could not load the SOMSDS structure: $!";
}

unless (-e $conf_file) {
  my ($vol, $dir, $file) = File::Spec->splitpath($0);
  $conf_file = abs_path catfile($dir,'SOMSDS.ini');
}

$ds->{recording}->{$rec}->import_dir($dir, $fuse, $conf_file);
