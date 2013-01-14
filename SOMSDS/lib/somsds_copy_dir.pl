#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Copies a directory tree
# Documentation: utilities.txt

use strict;
use warnings;
use File::Copy::Recursive 'dircopy';

my ($source, $target) = (shift, shift);

unless ($source && $target){
  print "
  
  Usage:
  
  somsds_copy_dir sourcedir targetdir
  
  Where:
  
  sourcedir       The directory to be copied
  
  targetdir        The name of the new directory
  
  ";
  die "\n";
}

$source = File::Spec->rel2abs($source);
$target = File::Spec->rel2abs($target);

system('somsds_fix_links '.$source.' --makeabs');

dircopy($source,$target) or die "Failed: $!\n";

system('somsds_fix_links '.$target.' --old '.$source.' --new '.$target.' --force');

