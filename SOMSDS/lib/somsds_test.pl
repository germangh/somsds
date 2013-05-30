#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Tests SOMSDS scripts
# Documentation: utilities.txt


use SOMSDS;
use Cwd;
use File::Spec::Functions;



# Create a new SOMSDS structure
my %tests;
for (qw(1 2 3 4 5)){
  $tests{$_} = '?';
}

my $root_path = catdir(cwd(), 'tests');
my $ds;
try {  
  $ds = SOMSDS->new($root_path);
} catch {
  $tests{1} = 'not ok';
}


