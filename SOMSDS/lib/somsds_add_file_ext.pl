#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Attach a file extension to a set of files
# Documentation: utilities.txt

use SOMSDS;
use Cwd;
use Getopt::Long;

my $folder;
my $help;
my $isdir;

GetOptions( "folder=s"     => \$folder,   
            "help"         => \$help,
            "isdir"        => \$isdir);
			
my ($regex, $fileext) = (shift, shift);

if ($help || !$regex || !$fileext){
  print "* Adds a file extension to a set of files
  
Usage: 

somsds_add_file_ext regex fileex [--]

Where:

regex             A (quoted) regular expression, e.g. ".+(orig|conv).+"

fileex            A file extension, e.g. .nii.gz


## OPTIONS
  
  --folder <dir>  Root folder where to start the file search

  --isdir 	  If this flag is used, then only directories will be renamed

  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}

unless($folder){$folder = cwd();}

SOMSDS::add_file_ext($regex, $fileext, $folder, $isdir);

