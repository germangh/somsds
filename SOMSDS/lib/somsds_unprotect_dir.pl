#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use File::Spec;

my $dir = shift;

if (!$dir){
  print "\n\n* Unprotect a directory and all its contents against accidental deletion
  
Usage: 

somsds_unprotect_dir path

Where:

path         The path to the directory that is to be protected

  \n";
  die "\n";
}

$dir = File::Spec->rel2abs($dir);

if ($dir eq '/data1' || $dir eq '/data1/recordings'){
    die "I can't let you unprotect everything under $dir!\n";
}

find(sub 
  {
    chmod 0755, $File::Find::name;
    my $cmd = "chattr -i \"$File::Find::name\"";
    print "$cmd\n";	
    system($cmd);
    $cmd = "chattr -a \"$File::Find::name\"";
    print "$cmd\n";
    system($cmd);
  },
  $dir
);
