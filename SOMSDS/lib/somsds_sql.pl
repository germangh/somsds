#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Performs a SQL query
# Documentation: utilities.txt

use SOMSDS;

use Getopt::Long;

my $root_path;
my $help;

GetOptions( "root=s"       => \$root_path,   
            "help"         => \$help);
			
my $query = shift;

if ($help || !$query){
  print "
Usage: somsds_sql QUERY
Performs a SQL query to the recordings database

  --root          Root location of the SOMSDS system. By default: /data
  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}


$ds = SOMSDS->new($root_path);

my $sth = $ds->sql($query);

if (ref($sth)){
  while (my $row = $sth->fetchrow_hashref){
    print join("\t", values %{$row}),"\n";
  }
}
