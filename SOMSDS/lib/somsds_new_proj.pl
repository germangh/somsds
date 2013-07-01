#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Creates a project directory tree
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;

my $root_path;
my $help;

GetOptions( "root=s"		              => \$root_path,						
            "help"                    => \$help
          );
			
my $id      = shift;
my $members = shift;

if ($help || !$id){
  print "* Creates a project folder structure
  
  Usage:
  
  somsds_new_proj projid members [--options]
  
  Where:
  
  projid          A project ID
  
  members         A comma separated list of user names. The first member of the
                  list will be the owner of the generated folder structure. A
                  user group with the same name as the project will be generated
                  and all the provided project members will be assigned to that
                  group
                  
 ## OPTIONS:
 
  --help          displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}


my $ds  = SOMSDS->new($root_path);

unless ($members){
  $members = getpwuid( $< );
}

my @members = split(',', $members);

$ds->make_proj_folders($id, \@members);
