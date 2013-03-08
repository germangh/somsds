#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Generate file descriptors
# Documentation: utilities.txt

use SOMSDS;
use SOMSDS::File;
use Getopt::Long;
use Cwd 'abs_path';
use File::Spec::Functions;


my $filename;
my $help;

GetOptions( "filename=s"   => \$filename,	   
            "conf=s"       => \@conf_file,   
            "help"         => \$help);
			

my $root = shift;
my $conf_file = shift;

if ($help || !$root){
  print "*Generates data file descriptors
  
Usage: 

somsds_describe dirname [--options]

Where:

dirname           A directory name


## COMMON OPTIONS

  --help          Displays this help. Run 'perldoc SOMSDS' for more help
\n";
  die "\n";
}

@conf_file   = split(/,/, $conf_file);

unless (@conf_file) {  
  my ($vol, $dir, $file) = File::Spec->splitpath($0);
  my $tmp = abs_path catfile($dir,'SOMSDS.ini');  
  if (-e $tmp){
    push @conf_file, $tmp;  
  }else{
    push @conf_file, '/etc/SOMSDS.ini';
  }
}

my @files;
foreach (@conf_file){
  if (-e $_){
    push @files, $_;
  }
}

unless (@files){
	my $files = join(',', @conf_file);
        die "I could not find any of the specified configuration file(s): $files\n";
    
}


File::descriptors($root, @conf_file);

