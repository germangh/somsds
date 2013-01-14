#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Removes empty directories
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

my $root_path;
my $doc;
my $help;

GetOptions( "doc" 				 => \$doc,
						"root=s"       => \$root_path,   
            "help"         => \$help);
			
my $rec = shift;

if ($help || !$rec){
  print "* Removes empty directories from a recording folder structure

Usage: 

somsds_prune_rec recid [--options]

Where:

recid             A recording ID

## OPTIONS

  --doc           Remove also doc directories

  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}


$ds = SOMSDS->new($root_path);

$ds->{recording}->{$rec}->prune($doc);
