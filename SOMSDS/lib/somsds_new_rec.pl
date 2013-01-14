#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Creates a recording directory tree
# Documentation: utilities.txt

use SOMSDS;
use SOMSDS::Recording 'new';
use Getopt::Long;
use Cwd 'abs_path';

use strict;
use warnings;

sub subject_ids($$);

my $tmp = '';
my $description;
my $responsible;
my @modalities;
my @conditions;
my @subjects_in;
my $ini_file;
my $id;
my $help;

GetOptions( "conf=s"                  => \$ini_file,
            "id=s"                    => \$id, 
            "subjects|subject=s"      => \@subjects_in,
            "conditions|condition=s"  => \@conditions,
            "modalities|modality=s"   => \@modalities,
            "description=s"           => \$description,
            "responsible=s"           => \$responsible,
            'tmp'                     => \$tmp,
            "help"                    => \$help);
			
my $settings_file = shift;

if ($help || !$settings_file){
  print "
  
  * Creates a new recording folder structure
  
  Usage: 
  
  somsds_new_rec settings [--options]

  Where:
  
  settings        A settings file that specifies all the relevant recording
                  properties: subjects, conditions, etc... 
                  Use somsds_new_rec_settings to generate such a file.


  ## COMMON OPTIONS:

  --tmp           generate only the folder structure without adding any info to
                  the database tables. If this option is used the folder 
                  will be generated in the current working directory

  --help          displays this help. Run 'perldoc SOMSDS' for more help\n";
  die "\n";
}

$settings_file = abs_path $settings_file;

my $somsds_obj = SOMSDS->new();

my $rec = Recording->new($settings_file, {tmp => $tmp});

if ($tmp){

  $rec->make_folders();

} else {

  $somsds_obj->recording($rec);
  #$rec->save($somsds_obj);

}
