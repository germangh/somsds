#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Sets permissions of a recording to 0755
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

my $root_path;
my $help;

GetOptions( "root=s"       => \$root_path,   
            "help"         => \$help);
			
my $rec = shift;

if (!$rec || $help){
  print "* Changes the permissions of a recording folder to 0755
  
Usage: 

somsds_unprotect_rec recid

Where:

recid             A recording ID


## COMMON OPTIONS:

  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}

$ds = SOMSDS->new($root_path);

unless (exists($ds->{recording}->{$rec})){
  die "Recording $rec does not exist\n";
}

$ds->{recording}->{$rec}->unprotect();


