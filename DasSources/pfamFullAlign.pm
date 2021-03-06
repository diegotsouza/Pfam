#########
# Author: rdf
# Maintainer: rdf
# Created: 2006-05-15
# Last Modified: 2006-05-15
# Builds DAS alignments from the pfam database
#
package Bio::Das::ProServer::SourceAdaptor::pfamFullAlign;

=head1 AUTHOR

Rob Finn <rdf@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use Storable qw(store);;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;

@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'alignment' => '1.0',
			     'features'  => '1.0',
			    };
}


=head2 build_alignment

 Title    : build_alignment
 Function : This is method connects to the data source via the transport layer. Form here,
          : it builds the alignment data structure.  This is specific to the data source
          : as different alignments have very different requirements in terms of which blocks
          : of xml are required.
 Args     : Alignment request parameters. The alignment acc (query), the rows (optional), a subject +/- a range (optional),
          : and a subject coos system. Pfam alignments only understand "ProteinSequence".
 Returns  : alignment data object

=cut


sub build_alignment {
    my ($self, $query, $rows, $subjectsRefs, $subCoos)   = @_;
    
    if($query =~ /(PF\d+)/i){
	my $acc = $1;
	my $all_pos;
	my $qacc = $self->transport->dbh->quote($acc);
        
	#Get the database version information;
	my $version = $self->transport->query("select pfam_release from VERSION");

	
	my $pfamAData = $self->transport->query(qq(SELECT  auto_pfamA, pfamA_id, pfamA_acc, num_full
						   FROM    pfamA
						   WHERE   pfamA_acc = $qacc)); 
	
        #Now get all of the alignment data
	my @statements;
	my $noSubjects;
	#Check that we can understand the subject coos system
	if($subCoos eq "" || $subCoos eq "ProteinSequence"){
	    
            #Build the sql to get the subjectsRefs
	    foreach my $subject (@$subjectsRefs){
		$noSubjects++;
		if($subject =~ /(\S+)\:(\d+)\,(\d+)/){
		    $subject = $1;
		    my $above = $2;
		    my $below = $3;
		    my $qsubject = $self->transport->dbh->quote($subject);

		    my $query;
		    
			$query = qq(SELECT tree_order 
				    FROM   pfamA_reg_full_significant, pfamseq
				    WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
				    AND    pfamA_reg_full_significant.auto_pfamseq = pfamseq.auto_pfamseq
				    AND    in_full=1
				    AND    pfamseq_acc=$qsubject); 
		    
		    
		    
		    my $subjectPos = $self->transport->query($query);
		    foreach my $posInfo (@$subjectPos){
			my $start = $posInfo->{'tree_order'} - $above;
			my $end = $posInfo->{'tree_order'} + $below;
			$all_pos .= "$start-$end,";
			
			
			    push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
						 FROM   pfamA_reg_full_significant, pfamseq
						 WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
						 AND    pfamA_reg_full_significant.auto_pfamseq = pfamseq.auto_pfamseq
						 AND    in_full=1
						 AND    tree_order <= $end
						 AND    tree_order >= $start));
			
		    }
		}else{
		    my $qsubject = $self->transport->dbh->quote($subject);

		    
			push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
					     FROM   pfamA_reg_full_significant, pfamseq
					     WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
					     AND    pfamA_reg_full_significant.auto_pfamseq = pfamseq.auto_pfamseq
					     AND    in_full=1
					     AND    pfamseq_acc=$qsubject));
		    
		    
		}
	    }
	    
	}
	if($rows){
	    my($start, $end) = split(/\-/, $rows);
	    $all_pos .= "$start-$end,";
	    
		push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
				     FROM   pfamA_reg_full_significant, pfamseq
				     WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
				     AND    pfamA_reg_full_significant.auto_pfamseq = pfamseq.auto_pfamseq
				     AND    in_full=1
				     AND    tree_order <= $end
				     AND    tree_order >= $start)) unless (!$start || !$end);
	    
	
	}

	if(!$rows && ! $noSubjects){
	    #get the whole alignment
	    
	
		push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
				     FROM   pfamA_reg_full_significant, pfamseq
				     WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
				     AND    pfamA_reg_full_significant.auto_pfamseq = pfamseq.auto_pfamseq
				     AND    in_full=1));
	
	    
	    }
	
	








	#Now execute all of the queries;
	my @allres;
	foreach my $sql (@statements){
	    push(@allres, @{$self->transport->query($sql)});
	}
	#By now we should have all of the raw alinment data
	

	my @aliObjects;
	my %seen;
	my @segments;
	foreach my $row (@allres){
	    if(!$seen{$row->{'pfamseq_acc'}}){
		my @objectDetails;
		
		push(@aliObjects, {'version' => $row->{'md5'},
				   'intID' => $row->{'pfamseq_acc'},
				   'type' => "PROTEIN",
				   'dbSource' => "Pfam",
				   'dbVersion' => $version->[0]->{'pfam_release'},
				   'coos' => "UniProt",
				   'accession' =>  $pfamAData->[0]->{'pfamA_acc'},
				   'aliObjectDetail' => \@objectDetails,
				   'sequence' => $row->{'sequence'}});
		
		$seen{$row->{'pfamseq_acc'}}++;
	    }
	    
	    push(@segments, { 'cigar'    => $row->{'cigar'},
			      'objectId' => $row->{'pfamseq_acc'},
			      'start'    => $row->{'seq_start'},
			      'end'      => $row->{'seq_end'}, });
	}
	
	my @blocks;
	push(@blocks, {'blockOrder' => 1,
		      'segments' => \@segments
		      });
	
	my @ali;
	push(@ali,  {
	    'type' => "Pfam Full Alignment",
	    'name' => $query,
	    'position' => "$rows",
	    'max' => $pfamAData->[0]->{'num_full'},
	    'alignObj' => \@aliObjects,
	    'blocks' => \@blocks,
	    'scores' => undef,
	    'geo3D' => undef, #Normally an array
	});
       
	return @ali;
    }
    
}


sub build_features{
    my ($self, $opts) = @_;
    my $segment       = $opts->{'segment'};
    my @features;
    if($segment =~ /(PF\d{5})/i){

	my $acc  = $1;
	
	
	my $qacc      = $self->transport->dbh->quote($acc);
  

	my $query         = qq(SELECT pfamA_id, pfamA_acc, full_consensus from pfamA where pfamA_acc = $qacc);
	
	my $ref           = $self->transport->query($query);
	
	my @features      = ();
	
	if($ref->[0]){
	    push @features, {
		'id'     => $ref->[0]->{'pfamA_id'}." full alignment consensus",
		'label'  => $ref->[0]->{'full_consensus'},
		'type'   => "Full Alignment Consensus",
		'method' => "consensus at 60% threshold",
	    };
	}
	
	return @features;
    }
}


sub segment_version {
    my ($self, $segment) = @_;
    my $version       = $self->transport->query(qq(SELECT pfam_release from VERSION));
    
    return $version->[0]->{'pfam_release'};
}
