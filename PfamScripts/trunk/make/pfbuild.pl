#!/usr/local/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Copy;

use Bio::Pfam::Config;
use Bio::Pfam::AlignPfam;
use Bio::Pfam::HMM::HMMResultsIO;
use Bio::Pfam::FamilyIO;
use Data::Dumper;
  
main( @ARGV ) unless caller(  );

sub main {

#-------------------------------------------------------------------------------
# Get the Pfam Config and check all is well.
  my $config = Bio::Pfam::Config->new;
  
  unless($config){
    die "Failed to obtain a Pfam Config object, check that the environment variable PFAM_CONFIG is set and the file is there!\n";
  }
  unless ($config->location eq 'WTSI' or $config->location eq 'JFRC'){
    warn "Unkown location.....things will probably break\n"; 
  }
  unless( -d $config->hmmer3bin){
    die "Could not find the HMMER3 bin directory,". $config->hmmer3bin ."\n";
  }
    
  
#-------------------------------------------------------------------------------
#Deal with the command line options
  
  my ($fname, $hand, $local, $nobuild, $nosplit, $help, $evalCut, $dbsize,
      $max, $bFilt, $null2, $f1, $f2, $f3, $ibm, $ism );

  &GetOptions( "help"       => \$help,
               "hand"       => \$hand,
               "ignoreBM"   => \$ibm,
               "ignoreSM"   => \$ism,
               "local"      => \$local,
               "nobuild"    => \$nobuild,
               "nosplit"    => \$nosplit,
               "E=s"        => \$evalCut,
               "Z=s"        => \$dbsize,
               "max"        => \$max,
               "biasfilter" => \$bFilt,
               'nonull2'    => \$null2,
               'F1=s'         => \$f1,
               'F2=s'         => \$f2,
               'F3=s'         => \$f3,);
  
  help() if($help);
  if($hand and $nobuild){
     warn "\n***** Can not specfiy -hand and -build together *****\n\n";
  }
  
  if($local){
    $nosplit = 1; 
  }

#-------------------------------------------------------------------------------
#Read in the DESC file.  This is now required!

  unless(-s 'DESC'){
     die "We now require a DESC file before runing $0\n";
  }

  my $io = Bio::Pfam::FamilyIO->new; 
  my $descObj = $io->parseDESC("DESC");
  

#-------------------------------------------------------------------------------
# If we are to run HMM build check the SEED and build options.
              
  # Do we have a SEED file and can we build an HMM for it.
  unless($nobuild){
    my %buildOpts;
    unless(-s 'SEED'){
      die "Could not locate the SEED file:[$!]\n";
    }
    open( SEED, "SEED" ) or die "FATAL: can't open SEED\n";
    open( SNEW, ">SEED.$$" ) or die "FATAL: can't write to SEED.$$\n";
    open( SNEWS, ">SEED.$$.selex" ) or die "FATAL: can't write to SEED.$$.selex\n";
    my $aln = Bio::Pfam::AlignPfam->new;
    #eval{
    #  $aln->read_stockholm( \*SEED );
    #};
  
    #Problem reading the alignment
    #if($@){
    #  warn "SEED alignment not in stockholm format, trying selex/Pfam format.\n";
    #}
    #Seed if it looks like a SEED in Pfam/Mul format
    eval{
      $aln->read_Pfam( \*SEED );
    };
  
    if($@){
      die "Failed to parse the SEED alignment\n";
    }
    
    #Now reformat the SEED alignment to make all - characters .  
    my $newaln = $aln->allgaps_columns_removed();
    $newaln->map_chars( '-', '.' );
    $newaln->write_stockholm( \*SNEW );
    $newaln->write_Pfam(\*SNEWS);
    
    
    if($newaln->match_states_string){
      $buildOpts{"--hand"} = 0;
      unless($hand){
        warn "Found #=RF line, switching on --hand options\n";  
      }
    }else{
     if($hand){
       die "You switched on -hand but found no #=RF line in the SEED.\n"
     } 
    }
    close SEED;
    close SNEW;
    close SNEWS;
    
    rename( "SEED", "SEED.old.$$" ) or die "FATAL: can't rename SEED\n";
    rename( "SEED.$$", "SEED" ) or die "FATAL: can't rename SEED.$$\n";

    $buildOpts{"-o"} = '/dev/null';    
    
    
   unless($ibm){
    my $line = $descObj->BM;
    if($line =~ /hmmbuild (.*) HMM/){
      while($line =~ /(-{1,2}\w+)\s+([A-Z0-9\.]){0,1}/g){
        my $optFlag = $1;
        my $optParam = $2 if($2);
        
        unless(defined($buildOpts{$optFlag})){
           if($optParam){
              $buildOpts{$optFlag} = $optParam; 
           }else{
              $buildOpts{$optFlag} = 0; 
           }
        }
        
      }
    }elsif($line =~ /hmmbuild\s+HMM/){
      ;
    }else{
      die "Did not recognise BM line ".$descObj->BM."\n";
    }
  }
  
    my $buildline = "hmmbuild ";
    foreach my $opt (keys %buildOpts){
      if($buildOpts{$opt}){
        $buildline .= " $opt ".$buildOpts{$opt}; 
      }else{
        $buildline .= " $opt";
      }
    }    
   
   
   
   
   
    $buildline .= " HMM SEED";
    
    $descObj->BM($buildline);
    
    #Now run hmmbuild
    system($config->hmmer3bin."/".$buildline) and die "Error building hmm!\n";
    unless(-s "HMM"){
      die "Failed to run HMM build. Although it seems to have run successfully, the HMM has no size or is absent\n"; 
    }
    
    rename( "SEED.$$.selex", "SEED" ) or die "FATAL: can't rename SEED.$$\n";
    
  }else{
    # Skip hmmbuild if no build
    unless( -s "HMM" ){
      die "Could not find the HMM file:[$!]\n";
    } 
  }

#-------------------------------------------------------------------------------
# Now build up the hmmsearch options 

  # Now build and search
  my %searchOptions;
  
  # E-value cut off
  unless($evalCut){
    $evalCut = 1000;
  }
  unless($evalCut > 0) {
    die "You can not specifiy a E-value cutoff less than 0\n"; 
  }
  $searchOptions{"--seqE"} =  $evalCut;
  
  
  # database size
  if($dbsize){
    if($dbsize != $config->dbsize){
      warn "\n***** Using effective database size [$dbsize] that is different to pfamseq [".
            $config->dbsize."] *****\n\n";
    } 
  }else{
    $dbsize =  $config->dbsize;
  }
  unless($dbsize > 0) {
    die "You can not specifiy a database size smaller than 1\n"; 
  }
  unless(int($dbsize) == $dbsize){
    die "dbsise($dbsize) must be an integer\n"; 
  }
  $searchOptions{'--seqZ'} = $config->dbsize;
  
  # Turn off heuristic filtering
  if($max){
    if($local){
      warn "\n***** This will take a while to run *****\n\n"; 
    }
    $searchOptions{"--max"} = 0; 
  }
  
  if($bFilt){
    $searchOptions{"--biasfilter"} = 0; 
  }
  
  if($null2){
    warn "\n***** Switching off biased sequence correction scores *****\n\n";
    $searchOptions{"--nonull2"} = 0;  
  }
  
  if($f1){
    warn "\n***** Setting the multi sequence viterbi threshold to $f1 *****\n";
    $searchOptions{"--F1"} = $f1;  
  }
  if($f2){
    warn "\n***** Setting viterbi threshold to $f2 *****\n";
    $searchOptions{"--F2"} = $f2;  
  }
  if($f3){
    warn "\n***** Setting the Forward score filter to $f3 *****\n";
    $searchOptions{"--F3"} =  $f3;  
  }
  
  unless($ism){
    my $line = $descObj->SM;
    if($line =~ /hmmsearch (.*) HMM/){
      while($line =~ /(-{1,2}\w+)\s+([A-Z0-9\.]){0,1}/g){
        my $optFlag = $1;
        my $optParam = $2 if($2);
        
        unless(defined($searchOptions{$optFlag})){
           if($optParam){
              $searchOptions{$optFlag} = $optParam; 
           }else{
              $searchOptions{$optFlag} = 0; 
           }
        }
        
      }
    }elsif($line =~ /hmmsearch\s+HMM/){
      ;
    }else{
      die "Did not reecognise SM line ".$descObj->SM."\n";
    }
  }
  
  my $searchOptions = 'hmmsearch';
  foreach my $opt (keys %searchOptions){
    if($searchOptions{$opt}){
      $searchOptions .= " $opt ".$searchOptions{$opt}; 
    }else{
      $searchOptions .= " $opt"; 
    } 
  }
  $searchOptions .= " HMM";
  
#-------------------------------------------------------------------------------    
#  
  
  my $cmd;
  my $HMMResultsIO = Bio::Pfam::HMM::HMMResultsIO->new;  
  if($nosplit){
    $cmd =$config->hmmer3bin."/".$searchOptions." ".$config->pfamseqLoc."/pfamseq > OUTPUT";
    $descObj->SM($searchOptions." pfamseq");
  }
  
  #Okay if we get here, this is a great chance of success!
  rename("DESC", "DESC.b4.pfbuild") or die "Could not move DESC to DESC.b4.pfbuild";
  $io->writeDESC( $descObj );
  
  unlink('PFAMOUT');
  unlink('OUTPUT');
  
  if($local){
    system($cmd) 
      and die "Failed to run hmmbuild [ $cmd ] due to [$!]";
    #Parse the Results
    $HMMResultsIO->convertHMMSearch( "OUTPUT" );
  }else{
    
    
    
    #We are going to use some sort of farm! 
    my $farmConfig = $config->farm;
    unless($farmConfig){
      die "Failed to get a farm configuration file\n"; 
    }
    if($farmConfig->{sge}){
      if($nosplit){
        system("qsub -N pfamHmmSearch -j y -o /dev/null -b y -cwd -V \'$cmd\'") and die "Failed to submit job to SGE,qsub -N pfamHmmSearch -j -o /dev/null -b y -cwd -V \'$cmd\' \n";  
      }else{
        #TODO split
        print STDERR "TODO: nothing run:\n"
      } 
    }elsif($farmConfig->{lsf}){
      if($nosplit){
        
        
        
        #system("qsub -N pfamHmmSearch -j y -o /dev/null -b y -cwd -V \'$cmd\'") and die "Failed to submit job to SGE,qsub -N pfamHmmSearch -j -o /dev/null -b y -cwd -V \'$cmd\' \n";  
      }else{
        #TODO split
        print STDERR "TODO: nothing run:\n"
      } 
    }else{
      die "Unknown farm set-up\n"; 
    }
  }

  print STDERR "Finished\n";
}

sub help {


print<<EOF;

Command line options for controlling $0 
-------------------------------------------------------------------------------

  -help       : prints this help messeage

If you do not understand any of the options below, just run without any options.

Options that influence hmmbuild:

  -nobuild    : If you have already built the HMM and do not want to build 
              : it again.
  -hand       : When there is an #=RF line in the SEED alignment, this option 
              : should be switched on.  The #=RF line dictates which residues are 
              : matche states. In Pfam, this is often used to mask out nested 
              : domanins.
  -ignoreBM   : Ignore the BM line present in the DESC file. Otherwise the BM
              : line will be supplimented to your BM options.  
              
  Both of these options can not be supplied together;

  *** There are more specialised options to come ***

Options that influence hmmsearch:

  General wrapping options:
  -local      : Run the hmmsearch on the local machine rather than submitting 
              : to a compute farm. Note, the farm configuration is used by the 
              : Pfam configuration file.
  -nosplit    : Run the search a one system call against the whole of pfamseq.  
              : Without this option, hmmsearch is run against the split version 
              : of pfamseq.
  -ignoreSM   : Ignore the SM line present in the DESC file. Otherwise the SM
              : line will be supplimented to your SM options.            
              
  Note, if -local is specified then nosplit is switched on.
  
  Options controlling significance thresholds for reporting:
  -E <x>      : E-value cutoff for reporting sequences  [default 1000].
  -Z <x>      : Effective size of the sequence database for E-value calculation
              : This should be an unsigned integer.  [default is size of pfamseq
              : grabbed from the Pfam config].
              
  Note both -E and -Z only effect the sequence parameters and not the --domE and 
  --domZ parameters in HMMER3.  
   
  Options controlling acceleration heuristics:
  -max        : Turn all heuristic filters off (increase sensitivity). This is 
              : not recommended for genral Pfam building as it will run very slowly, 
              : but useful for ensuring that no sequences are rejected by the 
              : filtering.
  -biasfilter : Turn on composition bias filter.  This can increase speed in some 
              : cases where there the query domain has bias composition 
              : e.g. transmembrane domains. 

Options for gurus:
  -nonull2    : turn off biased sequence composition corrections to scores    
  -F1 <x>     : Stage 1 (MSV) threshold: promote hits w/ P <= F1  [0.02]
  -F2 <x>     : Stage 2 (Vit) threshold: promote hits w/ P <= F2  [1e-3]
  -F3 <x>     : Stage 3 (Fwd) threshold: promote hits w/ P <= F3  [1e-5]
  
  Note, option -max is incompatible with option(s) -F1,-F2,-F3
  
EOF

exit(1);

}




