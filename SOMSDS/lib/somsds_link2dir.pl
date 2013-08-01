#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Generates symbolic links to all files within a directory
# Documentation: utilities.txt

use strict;
use warnings;
use Config::IniFiles;
use File::Spec;
use File::Find;
use Shell::Command;
use File::Copy;

my ($dirIn, $dirOut) = (shift, shift);

unless ($dirIn && $dirOut){
  print "
  
  Usage:
  
  somsds_link2dir sourcedir outdir
  
  Where:
  
  sourcedir       The directory to which we want to link
  
  outdir          The name of the generated directory
  
  ";
  die "\n";
}

$dirIn  = File::Spec->rel2abs($dirIn);
$dirOut = File::Spec->rel2abs($dirOut);

unless (-d $dirOut){
  mkpath $dirOut;
}


find (\&make_symlink, $dirIn);

print "\n";

sub make_symlink() {
print $File::Find::name,"\n";
  if (-l $File::Find::name){
    # Just copy the symblink
    my $path = $File::Find::dir;
    $path =~ s/^$dirIn//;
    my $linkName = File::Spec->catfile($dirOut, $path, $_);    
    $path = File::Spec->catdir($dirOut, $path);
    mkpath $path;
    my $target = readlink($File::Find::name);
    symlink $target, $linkName or die "Couldn't create link $linkName: $!\n";
    print "$linkName\n----->$target\n"; 
  } elsif (-d $File::Find::name){
    # Create a directory with the same name
    my $path = $File::Find::name;
    $path =~ s/^$dirIn//;
    my $newDir = File::Spec->catdir($dirOut, $path);
    unless (-d $newDir){
      mkpath $newDir;
    }
  } else {
    # Create a symbolic link
    my $path = $File::Find::dir;
    $path =~ s/^$dirIn//;
    my $linkName = File::Spec->catfile($dirOut, $path, $_);    
    $path = File::Spec->catdir($dirOut, $path);
    mkpath $path;
    symlink $File::Find::name, $linkName or die "Couldn't create link $linkName: $!\n";
    print "$linkName\n----->$File::Find::name\n"; 
  }
} 
