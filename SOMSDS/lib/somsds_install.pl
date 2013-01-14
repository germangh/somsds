#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Installs the smri package
# Documentation: utilities.txt


use Cwd qw(abs_path cwd);
use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use File::Copy;

my ($module, $bin_dir, $conf_dir) = (shift, shift, shift);

my $def_bin_dir;
my $def_conf_dir;
my $def_module;
if ($^O eq 'darwin'){
  # If we are in Mac OS X
  $def_bin_dir 	= "$ENV{HOME}/bin"; 
  $def_conf_dir = '/etc';
  $def_module   = '/usr/local/ActivePerl-5.14/site/lib';
} elsif ($^O eq 'MSWin32'){
  # If we are running windows at NIN271
  $def_bin_dir  = 'C:/strawberry/perl/bin';
  $def_conf_dir = 'C:/strawberry/perl/lib';
  $def_module   = 'C:/strawberry/perl/lib';
}elsif ($^O eq 'cygwin'){
  $def_bin_dir  = '/usr/local/bin';
  $def_conf_dir = '/etc';
  $def_module   = '/usr/lib/perl5/5.10';
} else {
  # At somerenserver
  $def_bin_dir  = '/usr/local/bin';
  $def_conf_dir = '/etc';
  $def_module   = '/usr/local/lib/site_perl';
}

unless($bin_dir){$bin_dir = $def_bin_dir;}
unless($conf_dir){$conf_dir = $def_conf_dir;}
unless($module) {$module = $def_module;}

print "Installing binary files in: $bin_dir\n";
print "Installing config files in: $conf_dir\n";
print "Installing perl module in:  $module\n\n\n";

# Copy module into destination directory
my $dir_from = catdir(cwd(), 'SOMSDS') ;
my $dir_to   = catdir($module,'SOMSDS');
dircopy($dir_from, $dir_to) or die "Copy failed: $!"; 
print "dircopy $dir_from $dir_to\n";
chmod (0755, catdir($module,'SOMSDS')) or die "Coudn't chmod $file: $!";
        
# Copy scripts to the perl libraries directory and generate symbolic links to them
foreach (qw(somsds_archive_rec somsds_unarchive_rec somsds_describe
            somsds_new somsds_new_rec somsds_new_rec_settings
            somsds_remove_rec somsds_protect_rec
            somsds_unprotect_rec somsds_prune_rec somsds_sql somsds_update_rec
            somsds_import_rec somsds_rec_get somsds_new_proj somsds_link2rec 
            somsds_add_file_ext somsds_get somsds_link2dir
            somsds_broken_links somsds_fix_links somsds_copy_dir
            somsds_gunzip somsds_rec_list somsds_protect_dir somsds_unprotect_dir)){
  my $file = catfile(catdir($module, 'SOMSDS'), $_.'.pl');
  copy($_.'.pl', $file) or die "Copy $_.pl -> $file failed: $!";
  print "copy $_.pl $file\n";
  chmod (0755, $file) or die "Coudn't chmod $file: $!";  
  my $link_name = catfile($bin_dir, $_);
  if ($^O =~ m/^MSWin/){ 
    copy($file, $link_name.'.pl') or die "Couldn't copy to location $link_name.pl: $!";
	print "copy $file $link_name.pl\n";
  }else{
    symlink $file, $link_name or die "Couldn't create link $link_name: $!";
	print "symlink $file $link_name\n";
  }
  
}

# Copy the module file and the configuration file
$file = catfile($module, "SOMSDS.pm");
copy("SOMSDS.pm", $file) or die "Copy failed: $!";
chmod 0755, $file;

# Configuration files
foreach (qw(SOMSDS.ini)){
  my $file = catfile($module, 'SOMSDS', $_);
  copy($_, $file ) or die "Copy failed: $!";
  print "copy $_ $file\n";
  my $link_name = catfile($conf_dir, $_);
  if ($^O =~ m/^MSWin/){ 
    copy($file, $link_name) or die "Couldn't copy to location $link_name: $!";
	print "copy $file $link_name\n";
  }else{
    symlink $file, $link_name or die "Couldn't create link $link_name: $!";
	print "symlink $file $link_name\n";
  }  
  print "symlink $file $link_name\n";
  my $link_name = catfile($bin_dir, $_);
  if ($^O =~ m/^MSWin/){ 
    copy($file, $link_name) or die "Couldn't copy to location $link_name: $!";
	print "copy $file $link_name\n";
  }else{
    symlink $file, $link_name or die "Couldn't create link $link_name: $!";
	print "symlink $file $link_name\n";
  }  
  chmod (0755, $file) or die "Coudn't chmod $file: $!";
  print "chmod 0755 $file\n";
}  
