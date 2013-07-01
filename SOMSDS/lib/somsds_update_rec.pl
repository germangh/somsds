#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Updates the symbolic links of a recording
# Documentation: utilities.txt


use SOMSDS;

use Getopt::Long;

my $root_path;
my $help;

GetOptions( "root=s"       => \$root_path,   
            "help"         => \$help);
			
my $rec = shift;

if ($help || !$rec){
  print "* Updates the list of files of a recording
  
Usage: 

somsds_update_rec recid

Where:

recid             A recording ID


## OPTIONS
  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}


$ds = SOMSDS->new($root_path);

$ds->update_file_list($rec);
