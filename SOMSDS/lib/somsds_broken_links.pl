#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Fixes symbolic links within a directory
# Documentation: utilities.txt

use strict;
use warnings;
use Config::IniFiles;
use File::Spec;
use File::Find;
use Shell::Command;

my $dir = shift;

unless ($dir){
  print "
  Lists broken symbolic links within a directory
  
  Usage:
  
  somsds_broken_links directory
  
  Where:
  
  directory       The directory tree where the symbolic links are contained
  
  
  ";
  die "\n";
}

$dir  = File::Spec->rel2abs($dir);

find (\&is_broken, $dir);

print "\n";

sub is_broken() {
  unless (-l $File::Find::name && !-e){ return;}
  if (defined(my $target = readlink($File::Find::name))){
  	print "$File::Find::name \n--->>>$target\n\n";
  } else {
  	print "[empty]"
  }
} 

