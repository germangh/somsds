#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Removes a recording
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

use strict;
use warnings;

my $help;

GetOptions( "help"         => \$help);
			
my $rec = shift;

if ($help || !$rec){
  print "*Removes a recording from the SOMSDS database
  
Usage: 

somsds_remove_rec recid [--options]

Where

recid             The ID of the recording that is to be removed


## OPTIONS
  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}


my $ds = SOMSDS->new();

$ds->remove_rec($rec);
