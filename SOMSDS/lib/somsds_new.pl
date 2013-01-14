#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Initializes the SOMSDS structure
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

my $root_path;
my $help;

GetOptions( 'root=s'        => \$root_path,
            'help'          => \$help);
			
my $root_path = shift;

if ($help){
  print "
  * Creates a new SOMSDS data structure
  
  Usage: 
  
  somsds_new
";
  die "\n";
}

SOMSDS->new($root_path);

