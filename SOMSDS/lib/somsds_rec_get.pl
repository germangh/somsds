#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Inspect properties of a recording
# Documentation: utilities.txt

use SOMSDS;

use Getopt::Long;
use Text::Table;

my $root_path;
my $help;

GetOptions( "root=s"       => \$root_path,   
            "help"         => \$help);
			
my ($rec, $prop) = (shift,shift);

if ($help || !$rec || !$prop){
  print "
Usage: 

somsds_rec_get recid propname

Where:

recid             A recording ID

propname          A property name (the name of a column in the files.csv table)


## OPTIONS

  
  --help          Displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}


$ds = SOMSDS->new($root_path);

my $sth = $ds->sql("SELECT * FROM recordings.csv WHERE id LIKE '$rec'");

my $row = $sth->fetchrow_hashref();

my $cfg_file = $ds->{recording}->{$rec}->{settings_file};

my $cfg = new Config::IniFiles(-file => $cfg_file);
  

# List of information items
my @items = split(/,/, $prop);
my $tb;
foreach (@items){
  my @prop_values = $cfg->GroupMembers($_);
  my @props = $cfg->Parameters($prop_values[0]);
  my @col_names   = ($_, @props);

  my @rule      = qw(- +);
  my @headers   = \'| ';
  push @headers => map { $_ => \' | ' } @col_names;
  pop  @headers;
  push @headers => \' |';
  $tb = Text::Table->new(@headers);
  print "\n\n";
  print "$_ values for recording $rec\n";
  print "-------------------\n\n";
  for my $prop_val (@prop_values){
    my $short_item_val = $prop_val;
    $short_item_val=~s/$_\s+//;
    my @col_val = ($short_item_val);
    for my $prop (@props){
      push @col_val, $cfg->val($prop_val, $prop);
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


