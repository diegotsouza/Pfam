#!/usr/bin/perl
#
# Authors: Rob Finn & John Tate 
#
# This script is designed to take jobs entered into the web_user database
# and run them.  This dequeuer will run non-interactive jobs. This is heavily
# tied to the WTSI LSF queue and will require tweaking for those wishing to run
# locally.  This performs some downweighting of users, but this is tied to LSF.
# If the config does not have a thirdParty queue set, then the jobs will be run by
# this dequeuer.
#
# The jobs that are non-interactive are:
# 1. single DNA sequence searches
# 2. batch protein searches
#
# In this script, there are three parts to the job:
# 1. Get the query data into a file so it is on the local machine.
# 2. Run the executable - pfam_scan.pl or pfamdna_search.pl
# 3. Once the job has finished the results are emailed to the users and entered in the database.
#
# There are no reasons that these could not be combined, but we use the pfam_scan.pl script elsewhere 
# and want maintain it's current functionality. The fasta file writing in not performed in this
# dequeuer compared with fast- or hmmer- dequeues as at WTSI we use a third party LSF queue,
# and machine that this job runs on is different to the execution machine.
#
use strict;
use warnings;
use Data::Dumper;
use IPC::Cmd qw(run);
use IO::File;
use Getopt::Long;

# Our Module Found in Pfam-Core
use Bio::Pfam::WebServices::PfamQueue;

our $DEBUG = 0;



# Get a new queue stub
my $qsout = Bio::Pfam::WebServices::PfamQueue->new("slow");

while(1) {
  my $ref   = $qsout->satisfy_pending_job();
  $DEBUG && print Dumper($ref, $qsout->{'jobTypes'});
  
  unless($ref->{'id'}) {
   	sleep 5; #Poll the database every 5 seconds....3 per LSF Poll
  }else{	
  	my $error = 0;    
	my $cmd;
	
	
	if($ref->{'job_type'} eq "batch"){
		$cmd = "preJob.pl -id ".$ref->{id}." -tmp ".$qsout->tmpDir." && ";
		$cmd .= " ".$ref->{'command'};
		if($qsout->pvm){
			$cmd .= " -pvm"
		}else{
			$cmd .= " -cpu ".$qsout->cpus;
		}
		$cmd .= " -d ".$qsout->dataFileDir;
		$cmd .= " ".$ref->{'options'};
		$cmd .= " ".$qsout->tmpDir."/".$ref->{job_id}.".fa";
		$cmd .= " > ".$qsout->tmpDir."/".$ref->{job_id}.".res 2> ".$qsout->tmpDir."/".$ref->{job_id}.".err";
		$cmd .= " && postJob.pl -id ".$ref->{id}." -tmp ".$qsout->tmpDir;
	}elsif($ref->{'job_type'} eq "dna"){
		$cmd = "preJob.pl -id ".$ref->{id}." -tmp ".$qsout->tmpDir." && ";
		$cmd .= " ".$ref->{'command'};
		$cmd .= " -in ".$ref->{job_id}.".fa";
		$cmd .= " -tmp ".$qsout->tmpDir;
		$cmd .= " -data ".$qsout->dataFileDir;
		$cmd .= " -cpu ".$qsout->cpus;
		$cmd .= " > ".$qsout->tmpDir."/".$ref->{job_id}.".res 2> ".$qsout->tmpDir."/".$ref->{job_id}.".err";
		$cmd .= " && postJob.pl -id ".$ref->{id}." -tmp ".$qsout->tmpDir;
	}
	$DEBUG && print STDERR "Submitting id=$ref->{'id'}, command=$cmd\n";
	
	#Now for the lsf bit
	if($cmd) {
		print STDERR "$cmd";
		
		if($qsout->thirdPartyQueue eq 'WTSI'){
			  #Work out the Users priority
			  my $c = $qsout->numberPendingJobs($ref->{'email'});
			  my $p = 50 - $c;
			  $p =1 if($p < 1);
			  #Now set up the LSF job
			  my $fh = IO::File->new;
 		      $fh->open( "| bsub -q pfam_slow -sp $c -n ".$qsout->cpus." -R \"span[hosts=1]\"");
 		      $fh->print( "$cmd\n");
     		  $fh->close;
		}else{
			system( $cmd );
		}
		
 	}else{
		$error .= "unrecognised command line, commoand=$ref->{'command'}\n";
	}
	
	if($error){		
		$qsout->update_job_status($ref->{id}, 'FAIL');
		$qsout->update_job_stream($ref->{id}, 'stderr', $error);
		next;
	}
    
  } 
}

exit(0);
