#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Rename files
# Documentation: utilities.txt

use SOMSDS;
use Cwd;
use Getopt::Long;

my $folder;
my $help;

GetOptions( "folder=s"     => \$folder,   
            "help"         => \$help);
			
my ($regex1, $regex2) = (shift, shift);

if ($help || !$regex1 || !$regex2){
print "* Rename files
  
Usage: 

somsds_file_rename match subst [--]

Where:

match             A (quoted) regular expression

subst             Another (quoted) regular expression


## OPTIONS
  
  --folder        Root folder where to start the file search

  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}

unless($folder){$folder = cwd();}

SOMSDS::file_rename($regex1, $regex2, $folder);

