#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Inspects SOMSDS properties
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;
use Config::IniFiles;
use Text::Table;
use Cwd 'abs_path';
use File::Spec::Functions;

use strict;
use warnings;

sub subject_ids($$);

my $help;

GetOptions("help"                    => \$help);
			
my $item = shift;

if ($help || !$item){
  print "
  
  * Lists valid modalities, techniques, devices, etc...
  
  Usage: 
  
  somsds_get item [--options]

  Where:
  
  item            A string identifying an information item, e.g.: modality. Other
                  possibilities are: technique, device. You can also specify 
                  multiple information items as a comma separated list.                 


  ## OPTIONS:

  --help          displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}

# Read configuration file SOMSDS.ini
my ($vol, $dir, $file) = File::Spec->splitpath($0);
my $somsds_cfg_file; 
if (-e abs_path catfile($dir,'SOMSDS.ini')){
  $somsds_cfg_file = abs_path catfile($dir,'SOMSDS.ini');  
}else{
  $somsds_cfg_file = '/etc/SOMSDS.ini'; 
} 
 
my $somsds_cfg = new Config::IniFiles(-file => $somsds_cfg_file);
  

# List of information items
my @items = split(/,/, $item);
my $tb;
foreach (@items){
  my @item_values = $somsds_cfg->GroupMembers($_);
  my @props = $somsds_cfg->Parameters($item_values[0]);
  my @col_names   = ($_, @props);
  my @rule      = qw(- +);
  my @headers   = \'| ';
  push @headers => map { $_ => \' | ' } @col_names;
  pop  @headers;
  push @headers => \' |';
  $tb = Text::Table->new(@headers);
  print "\n\n";
  print "Valid $_ values\n";
  print "-------------------\n\n";
  for my $item_val (@item_values){
    my $short_item_val = $item_val;
    $short_item_val=~s/$_\s+//;
    my @col_val = ($short_item_val);
    for my $prop (@props){
      push @col_val, $somsds_cfg->val($item_val, $prop);
    }  
    $tb->load(\@col_val);
  }
  print $tb->rule(qw(- +)),
    $tb->title,
    $tb->rule(qw(- +)),
    $tb->body,
    $tb->rule(@rule);
  print "\n";
}



