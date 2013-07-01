#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Inspect properties of a recording
# Documentation: utilities.txt

use SOMSDS;
use Text::Table;

$ds = SOMSDS->new();

my @recs = keys %{$ds->{recording}};

my @colNames  = ('id', 'responsible', 'description');

my @rule      = qw(- +);
my @headers   = \'| ';
push @headers => map { $_ => \' | ' } @colNames;
pop  @headers;
push @headers => \' |';
my $tb = Text::Table->new(@headers);
print "\n\n";
print "List of available recordings\n";
print "-------------------\n\n";
for my $rec (@recs){
  my $cfg_file = $ds->{recording}->{$rec}->{settings_file};
  my $cfg = new Config::IniFiles(-file => $cfg_file);
  my @colVal = ($rec);
  for my $prop (@colNames){
    push @colVal, $cfg->val('recording '.$rec, $prop);
  }  
  $tb->load(\@colVal);
}
print $tb->rule(qw(- +)),
  $tb->title,
  $tb->rule(qw(- +)),
  $tb->body,
  $tb->rule(@rule);
print "\n";



