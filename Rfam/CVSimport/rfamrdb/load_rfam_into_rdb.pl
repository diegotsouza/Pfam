#!/usr/local/bin/perl 

use lib '/nfs/WWWdev/SANGER_docs/cgi-bin/Rfam';

use RfamWWWConfig;
use EntryWWW;

use lib '/nfs/disk56/mm1/rfam/scripts/Modules';

require "/nfs/disk56/mm1/rfam/scripts/Modules/UpdateRDB.pm";
require "/nfs/disk56/mm1/rfam/scripts/Modules/Bio/Rfam.pm";

#use UpdateRDB;
#use Rfam;

use strict;

my @arr = qw(RF00001 RF00002 RF00003 RF00004 RF00005 RF00006 RF00007 RF00008 RF00009 RF00010 RF00011 RF00012 RF00013 RF00014 RF00015 RF00016 RF00017 RF00018 RF00019 RF00020 RF00021 RF00022 RF00023 RF00024 RF00025);


foreach (@arr) {
  
  my $en;
  
  my $qacc = $_;
  
  my ($db, $id, $author, $description, $model_length, $seed_source      , $alignment_method , $gathering_cutoff, $trusted_cutoff  , $noise_cutoff    , $comment         , $previous_id      , $cmbuild , $cmcalibrate  , $num_seed , $num_full );
  
  eval {
    
    $db = &RfamWWWConfig::get_database();
    
    $en = $db->get_Entry_by_acc( $qacc );
    
    $id = $en->id();
    
  };
  
  
  
  my  $rdb = Bio::Rfam->rdb_update();
  
  print "RDB: $rdb \n\n";

$rdb->check_in_Entry( $en );


}
