#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Uncompress .gzip files using OGE
# Documentation: utilities.txt

use SOMSDS;
use Cwd;
use Getopt::Long;

my $oge;
my $regex;
my $help;

GetOptions( "regex=s"     => \$regex,   
            "help"         => \$help, 
            "oge"          => \$oge);
			
my $folder = shift;

if ($help){
  print "* Uncompresses files using OGE
  
Usage: 

somsds_gunzip folder [--]

Where:

folder            Root folder where to start the file search


## OPTIONS
  
  --regex         A regular expression that matches the files that are to
                  to be decompressed. THIS IS NOT WORKING YET!

  --oge 	  If this flag is provided, the uncompression jobs will be
                  submitted to Oracle Sun Grid engine

  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}

unless($folder){$folder = cwd();}

SOMSDS::gunzip($folder, $regex, $oge);

