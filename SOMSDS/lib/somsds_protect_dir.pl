#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use File::Spec;

my $dir = shift;

if (!$dir){
  print "\n\n* Protect a directory and all its contents against accidental deletion
  
Usage: 

somsds_protect_dir path

Where:

path         The path to the directory that is to be protected

  \n";
  die "\n";
}

$dir = File::Spec->rel2abs($dir);

find(sub 
  {
    chmod 0555, $File::Find::name;
    my $cmd = "chattr -i \"$File::Find::name\"";
    print "$cmd\n";	
    system($cmd);
    $cmd = "chattr +a \"$File::Find::name\"";
    print "$cmd\n";
    system($cmd);
    unless (-d $File::Find::name){
      my $cmd = "chattr +i \"$File::Find::name\"";
      print "$cmd\n";
      system($cmd);
    }  
  },
  $dir
);
