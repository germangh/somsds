#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Create a template recording settings file
# Documentation: utilities.txt

use SOMSDS;
use Getopt::Long;
use Config::IniFiles;

use strict;
use warnings;

sub subject_ids($$);

my $filename;
my @subjects_in;
my @modalities;
my @conditions;
my $responsible;
my $description;
my $help;

my @techniques;
my @devices;
my @sessions;
my @blocks;
my @subjprops = qw(sex age);
my @modprops;
my @condprops = qw(description);

GetOptions( "filename=s"              => \$filename, 
            "subjects|subject=s"      => \@subjects_in,
	   		    "modalities|modality=s"   => \@modalities,
			      "conditions|condition=s"  => \@conditions,
            "responsible=s"           => \$responsible,
            "description=s"           => \$description,
            "help"                    => \$help, 
            "technique|techniques=s"  => \@techniques,
            "device|devices=s"        => \@devices, 
            "session|sessions=s"      => \@sessions,
            "blocks|block=s"          => \@blocks,
            "subjprops=s"             => \@subjprops,
            "modprops=s"              => \@modprops,
            "condprops=s"             => \@condprops);
			
# Recording ID
my $id = shift;

if ($help || !$id){
  print "* Creates a template text file with recording settings
  
  Usage: 
  
  perl somsds_new_rec_setttings  recid [--options]

  Where:

  recid           Recording ID


  ## COMMON OPTIONS:

  --filename      Name of the settings file. By default: [recid]_settings.ini

  --subjects      Comma separated list of subjects, e.g.: 1,2,3 or 1..6 

  --modalities    Comma separated list of modalities, e.g.: eeg, meg, smri. Note 
                  that the provided modalities must be listed as valid in the 
                  configuration file /etc/SOMSDS.etc. 

  --conditions    Comma separated list of conditions, e.g.: rs-eo,rs-ec

  --responsible   Username of the researcher responsible of the recording. This 
                  user will be granted ownwership of the recording folder

  --description   Free form description of the recording

  --help          Displays this help. Run 'perldoc SOMSDS' for more help


  ## LESS COMMON OPTIONS:

  --techniques    Comma separated list of techniques, e.g. t1, dti, dist, prox
                  Note that the provided techniques must be listed as valid in 
                  configuration file /etc/SOMSDS.etc

  --device        Comma separated list of devices, e.g. philips-spinoza, 
                  philips-amc, ge-vu
                  Note that the provided devices must be listed as valid in 
                  /etc/SOMSDS.etc

  --sessions      Comma separated list of session IDs. Sessions IDs do not need
                  to be numeric, e.g. before-sleep, after-sleep

  --blocks        Comma separated list of block IDs, e.g. 1,3,5                  
  
  --subjprops     Comma separated list of properties (i.e. 'features') of each
                  subject that should be specified in the configuration file. By
                  default the following subject properties will be considered:
                  sex, age, notes 

  --modprops      Comma separated list of properties for each modality. By 
                  default: ext, techniques, description. The ext property is  
                  a list of accepted file extensions for the modality. The 
                  techniques property is a list of accepted techniques.

  --condprops     Comma separated list of properties for each condition. By 
                  default: description\n";
  die "\n";
}

# Generate subject ids of the form 000x
my $subjects  = join(',', @subjects_in);
my @subjects = ();
if ($subjects){
  my @tmp_subjects = split(/\s*,\s*/, $subjects); 
  foreach (@tmp_subjects){    
    if ($_ =~ m/(\d+)\.\.(\d+)/){      
      my @this_subjects = subject_ids($1, $2);  
      @subjects = (@subjects, @this_subjects);      
    }elsif ($_ =~ m/^\d+$/){
      push @subjects, subject_ids($_, $_);  
    }else{
      push @subjects, $_;    
    }    
  }
}	

@modalities   = split(/,/, join(',', @modalities));
@conditions   = split(/,/, join(',', @conditions)); 
@techniques   = split(/,/, join(',', @techniques)); 
@devices      = split(/,/, join(',', @devices)); 
@sessions     = split(/,/, join(',', @sessions)); 
@blocks       = split(/,/, join(',', @blocks)); 

@subjprops    = split(/,/, join(',', @subjprops)); 
@modprops     = split(/,/, join(',', @modprops)); 
@condprops    = split(/,/, join(',', @modprops)); 

# Default file name
unless ($filename){
  $filename = $id.'_settings.ini';
}

my $options = {
  'recid'           => $id,
  'filename'        => $filename,
  'subject'         => \@subjects, 
  'modality'        => \@modalities,
  'condition'       => \@conditions,
  'responsible'     => $responsible,
  'description'     => $description,
  'device'          => \@devices,
  'technique'       => \@techniques,
  'session'         => \@sessions,
  'block'           => \@blocks,
  'subject_props'   => \@subjprops,
  'modality_props'  => \@modprops,
  'condition_props' => \@condprops};

SOMSDS::new_rec_settings($options);

sub subject_ids($$) {
  my ($first, $last) = (shift, shift);
  my @ids = ();
  for (my $i=$first; $i<=$last; ++$i){
    push @ids, "0"x(4-length("$i"))."$i";    
  }
  @ids;
}
