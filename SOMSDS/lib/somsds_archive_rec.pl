#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Archives a recording
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

my $root_path;
my $filename;
my $help;

GetOptions( "filename=s" => \$filename,	   
            "root=s"     => \$root_path,   
            "help"       => \$help);
			
my $rec = shift;

if ($help || !$rec){
  print "* Archives a recording
  
Usage: 

somsds_archive_rec recid

Where:

recid             A recording ID


## OPTIONS

  --filename      The archived filename, without file extension
  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}


my $ds = SOMSDS->new($root_path);

$ds->archive_rec($rec, $filename);
