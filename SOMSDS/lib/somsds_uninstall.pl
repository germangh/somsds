#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Uninstalls SOMSDS scripts
# Documentation: utilities.txt


use Cwd qw(abs_path cwd);
use File::Spec::Functions;
use File::Path qw(remove_tree);
use File::Which qw(which where);
use File::Basename;

# Find the location of the lib directory
if ($^O eq 'MSWin32'){
  my @lib_dir = File::Spec->splitdir(readlink(which('somsds_link2rec.pl')));
} else {
  my @lib_dir = File::Spec->splitdir(readlink(which('somsds_link2rec')));
}
pop @lib_dir;
pop @lib_dir;
$lib_dir = File::Spec->catdir(@lib_dir);

# Find the location of the bin directory
my $filename;
my $bin_dir;
if ($^O eq 'MSWin32') {
  ($filename, $bin_dir) = fileparse(which('somsds_link2rec.pl'));
} else { 
  ($filename, $bin_dir) = fileparse(which('somsds_link2rec'));
}

# Find the location of the configuration dir
if (-d '/etc'){
  $conf_dir = '/etc';
} elsif ($^O eq 'MSWin32'){
  $conf_dir = 'C:/strawberry/perl/lib';
}
  
print "Removing binary files from:   $bin_dir\n";
print "Removing config files in:     $conf_dir\n";
print "Installing perl module from:  $lib_dir\n\n\n";

my @files = qw(somsds_archive_rec somsds_unarchive_rec somsds_descriptor 
            somsds_new somsds_new_rec somsds_new_rec_settings 
            somsds_remove_rec somsds_protect_rec
            somsds_unprotect_rec somsds_prune_rec somsds_sql somsds_update_rec
            somsds_import_rec somsds_rec_get somsds_new_proj somsds_link2rec
            somsds_add_file_ext somsds_get somsds_describe somsds_link2dir
            somsds_broken_links somsds_fix_links somsds_copy_dir
            somsds_gunzip somsds_rec_list somsds_protect_dir somsds_unprotect_dir somsds_file_rename);
my @files_bin = map {catdir($bin_dir, $_)} @files;
my @files_module = map {catfile($lib_dir, 'SOMSDS', "$_.pl")} @files;

foreach (@files_bin, @files_module){ 
  unlink($_);
  print "unlink $_\n";
};

# Module file
my $file = catfile($lib_dir, "SOMSDS.pm");
unlink $file;

# Configuration files
foreach (qw(SOMSDS.ini)){
  my $file = catfile($lib_dir, 'SOMSDS', $_);
  unlink $file;
  print "unlink $file\n";
  $file = catfile($conf_dir, $_);
  unlink $file; 
  print "unlink $file\n";
  $file = catfile($bin_dir, $_);
  unlink $file; 
  print "unlink $file\n";
}
# Remove the module directory
my $dir = catdir($lib_dir, 'SOMSDS');
remove_tree $dir;
print "Removed $dir\n"
