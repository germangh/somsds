#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Fixes symbolic links within a directory
# Documentation: utilities.txt

use strict;
use warnings;
use Config::IniFiles;
use File::Spec::Functions;
use File::Find;
use Shell::Command;
use Getopt::Long;


my $help;
my $force;
my $makeabs;
my $makerel;
my $new='';
my $old;

GetOptions( 
            "help"                  => \$help, 
            "force"                 => \$force,
            "makeabs"							  => \$makeabs,
            "makerel"               => \$makerel,
            "new=s"                 => \$new,
            "old=s"                 => \$old
          );


my $dir = shift;

unless ($dir && ($old || $makerel || $makeabs)){
  print "
  
  Usage:
  
  somsds_fix_links directory [--]
  
  Where:
  
  directory       The directory tree where the symbolic links are contained
  
  
                  
  ## Accepted options:
  
  --force         Fix links, even if not broken. Useful when the links refer to
                  a temporary location, like a external drive.
  
  --makeabs       Force the links to have absolute target paths.
  
  --makerel       Force the links to have relative target paths.
  
  --old           A regular expression pattern to be matched against the target
                  of every broken link, or of every link within the directory 
                  tree (if the --force flag is used).
                  
  --new           What should replace the old pattern in the target of every 
                  broken link. If not provided then the old pattern will be 
                  simply removed from the target.
  
  --help          Display this help.
  
  ";
  die "\n";
}

$dir  = File::Spec->rel2abs($dir);
if ($old){$old  = canonpath(File::Spec->rel2abs($old));}
if ($new){$new  = canonpath(File::Spec->rel2abs($new));}

find (\&fix_symlink, $dir);


sub fix_symlink() {
  unless (-l $File::Find::name && 
    ($force || $makeabs || $makerel || !-e)){ return;}
  if (defined(my $target = readlink($File::Find::name))){
    print "\n";
    print "Before: $target\n";
    if ($makeabs || $makerel){
       $target = canonpath(File::Spec->rel2abs($target));
    }
    if ($makerel){
      $target = canonpath(File::Spec->abs2rel($target));
    }
    if ($old){$target =~ s%$old%$new%g;}
    print "After: $target\n";
    unlink $File::Find::name;
    symlink $target, $File::Find::name or die "Couldn't create link $File::Find::name: $!";    
  } else {
    print "\n";
  	print "Link $File::Find::name points nowhere: $!\n"
  }
} 

