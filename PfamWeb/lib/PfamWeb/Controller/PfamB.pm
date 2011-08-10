
# PfamB.pm
# jt6 20060809 WTSI
#
# Controller to build a PfamB  page.
#
# $Id: PfamB.pm,v 1.21 2009-11-18 14:39:29 jt6 Exp $

=head1 NAME

PfamWeb::Controller::PfamB - controller for PfamB pages

=cut

package PfamWeb::Controller::PfamB;

=head1 DESCRIPTION

A C<Controller> to handle pages for Pfam-B entries. This is heavily reliant
on the Family controller, which is responsible for deciding whether the input
parameters on the URL are pointing to a Pfam-B accession or ID.

$Id: PfamB.pm,v 1.21 2009-11-18 14:39:29 jt6 Exp $

=cut

use strict;
use warnings;

use Data::Dump qw( dump );

use base 'PfamWeb::Controller::Section';

# define the name of the section...
__PACKAGE__->config( SECTION => 'pfamb' );

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 begin : Private

Determines the accession/ID for the Pfam-B.

=cut

sub begin : Private {
  my ( $this, $c, $entry_arg ) = @_;

  # cache page for 12 hours
  $c->cache_page( 43200 ); 
  
  # see if the entry is specified as a parameter
  my $tainted_entry = $c->req->param('acc')   ||
                      $c->req->param('id')    ||
                      $c->req->param('entry') ||
                      $c->req->query_keywords || # accept getacc-style params
                      $entry_arg              ||
                      '';
  
  if ( $tainted_entry ) {
    $c->log->debug( 'PfamB::begin: got a tainted entry' )
      if $c->debug;
    ( $c->stash->{param_entry} ) = $tainted_entry =~ m/^([\w\.-]+)$/
  }
}

#-------------------------------------------------------------------------------

=head2 pfamb : Chained

End of a chain that captures the URLs for the Pfam-B family page.

=cut

sub pfamb : Chained( '/' )
            PathPart( 'pfamb' )
            CaptureArgs( 1 ) {
  my ( $this, $c, $entry_arg ) = @_;

  my $tainted_entry = $c->stash->{param_entry} ||
                      $entry_arg               ||
                      '';
  
  $c->log->debug( "Family::family: tainted_entry: |$tainted_entry|" )
    if $c->debug;

  my $entry;
  if ( $tainted_entry ) {
    # strip off family version numbers, if present
    ( $entry ) = $tainted_entry =~ m/^([\w\.-]+)(\.\d+)?$/;
    $c->stash->{errorMsg} = 'Invalid Pfam-B accession or ID' 
      unless defined $entry;
  }
  else {
    $c->stash->{errorMsg} = 'No Pfam-B accession or ID specified';
  }

  # retrieve data for the family
  $c->forward( 'get_data', [ $entry ] ) if defined $entry;
}

#-------------------------------------------------------------------------------

=head2 pfamb_page : Chained

Just stuffs the hash with extra information, such as summary data and 
database cross-references. 

=cut

sub pfamb_page : Chained( 'pfamb' )
                 PathPart( '' )
                 Args( 0 ) {
  my ( $this, $c ) = @_;

  return unless $c->stash->{pfam};

  $c->log->debug('PfamB::pfamb_page: generating a page for a PfamB' )
    if $c->debug;

  $c->forward( 'get_summary_data' );
  $c->forward( 'get_db_xrefs' );
}

#---------------------------------------

=head2 old_pfamb : Path

Deprecated. Stub to redirect to the chained action.

=cut

sub old_pfamb : Path( '/pfamb' ) {
  my ( $this, $c ) = @_;

  $c->log->debug( 'Family::old_pfamb: redirecting to "pfamb"' )
    if $c->debug;
  $c->res->redirect( $c->uri_for( '/pfamb/' . $c->stash->{param_entry} ) );
}

#-------------------------------------------------------------------------------

sub get_data : Private {
  my ( $this, $c, $entry ) = @_;

  my $rs = $c->model('PfamDB::Pfamb')
             ->search( [ { pfamb_acc => $entry },
                         { pfamb_id  => $entry } ] );
  my $pfam = $rs->first if defined $rs;
    
  return unless $pfam;
  
  $c->log->debug( 'Family::get_data: got a Pfam-B' ) if $c->debug;
  $c->stash->{pfam}      = $pfam;
  $c->stash->{acc}       = $pfam->pfamb_acc;
  $c->stash->{entryType} = 'B';
}

#-------------------------------------------------------------------------------

=head2 pfamB : Path

Just stuffs the hash with extra information, such as summary data and 
database cross-references. We rely on the Family controller having 
figured out what the Pfam-B entry is and retrieving the appropriate row
for us.

=cut

# sub pfamB : Path {
#   my ( $this, $c ) = @_;
# 
#   # we're done here unless there's an entry specified
#   unless ( defined $c->stash->{pfam} ) {
#     $c->log->warn( 'PfamB::default: no ID or accession' );
#     $c->stash->{errorMsg} = 'No valid Pfam-B ID or accession';
#     return;
#   }
# 
#   $c->log->debug('PfamB::default: generating a page for a PfamB' )
#     if $c->debug;
# 
#   $c->forward( 'get_summary_data' );
#   $c->forward( 'get_db_xrefs' );
# }

#-------------------------------------------------------------------------------

=head2 structures : Path

Populates the stash with the mapping and hands off to the appropriate template.

=cut

sub structures : Chained( 'pfamb' )
                 PathPart( 'structures' )
                 Args( 0 ) {
  my ( $this, $c ) = @_;

  $c->log->debug( 'PfamB::structures: acc: |'
		  . $c->stash->{acc}  . '|' .  $c->stash->{entryType}. '|')
    if $c->debug;

  my @mapping = $c->model('PfamDB::PdbPfambReg')
                  ->search( { auto_pfamB  => $c->stash->{pfam}->auto_pfamb },
                            { prefetch    => [ qw( pdb_id auto_pfamseq ) ] } );
  $c->stash->{pfamMaps} = \@mapping;
  $c->log->debug( 'PfamB::structures: found |' . scalar @mapping . '| mappings' )
    if $c->debug;
  
  $c->stash->{template} = 'components/blocks/family/structureTab.tt';
}

#---------------------------------------

=head2 old_structures : Path

Deprecated. Stub to redirect to the chained action.

=cut

sub old_structures : Path( '/pfamb/structures' ) {
  my ( $this, $c, $entry_arg ) = @_;

  $c->log->debug( 'Family:FamilyActions::old_structures: redirecting to "structures"' )
    if $c->debug;
  $c->res->redirect( $c->uri_for( '/pfamb/' . $c->stash->{param_entry} . '/structures' ) );
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 get_summary_data : Private

Retrieves the data items for the overview bar.

=cut

sub get_summary_data : Private {
  my ( $this, $c ) = @_;
  
  $c->log->debug( 'PfamB::get_summary_data: getting summary information for a PfamB' )
    if $c->debug;

  my %summaryData;

  # make things easier by getting hold of the auto_pfamA
  my $auto_pfam = $c->stash->{pfam}->auto_pfamb;

  #----------------------------------------

  # get the PDB details
  my @maps = $c->model('PfamDB::PdbPfambReg')
               ->search( { auto_pfamb   => $auto_pfam },
                         { prefetch    => [ 'pdb_id' ] } );
  $c->stash->{pfamMaps} = \@maps;

  # number of structures known for the domain
  my %pdb_unique = map {$_->pdb_id => $_} @maps;
  $c->stash->{pdbUnique} = \%pdb_unique;
  $c->log->debug( 'PfamB::get_summary_data: found |' . scalar @maps . '| mappings, |'
                  . scalar( keys %pdb_unique ) . '| unique structures' )
    if $c->debug;

  $summaryData{numStructures} = scalar( keys %pdb_unique );

  #----------------------------------------

  # count the number of architectures
  my @archAndSpecies = $c->model('PfamDB::Pfamseq')
                        ->search( { auto_pfamb => $auto_pfam },
                                  { prefetch  => [ 'pfamb_regs' ] } );
  $c->log->debug( 'PfamB::get_summary_data: found a total of |' 
                  . scalar @archAndSpecies . '| architectures' )
    if $c->debug;

  # count the *unique* architectures
  my $numArchs = 0;
  my %seenArch;
  foreach my $arch ( @archAndSpecies ) {
    if ( $arch->get_column('auto_architecture') ) {
      $c->log->debug( 'PfamB::get_summary_data: got an auto_architecture' )
        if $c->debug;

      $c->log->debug( 'PfamB::get_summary_data: auto_architecture (get_column): '
                      . $arch->get_column('auto_architecture') )
        if $c->debug;
      # $c->log->debug( 'PfamB::get_summary_data: auto_architecture (from rel):   '
      #                 . $arch->auto_architecture->auto_architecture )
      #   if $c->debug;

      $numArchs++ unless $seenArch{$arch->get_column('auto_architecture')};

      $seenArch{$arch->auto_architecture->auto_architecture}++;

      $c->log->debug( 'PfamB::get_summary_data: seenArch now '
                      . $seenArch{$arch->get_column('auto_architecture')} )
        if $c->debug;
    } 
    else {
      $c->log->debug( 'PfamB::get_summary_data: no architecture' )
        if $c->debug;
      $numArchs++ unless $seenArch{nopfama};
      $seenArch{nopfama}++;
    }
  }
  $c->log->debug( "PfamB::get_summary_data: found |$numArchs| *unique* architectures" )
    if $c->debug;

  # number of architectures....
  $summaryData{numArchitectures} = $numArchs;

  #----------------------------------------

  # number of sequences in full alignment
  $summaryData{numSequences} = $c->stash->{pfam}->number_regions; 

  #----------------------------------------

  # number of species
  my %species_unique = map {$_->species => 1} @archAndSpecies;
  $summaryData{numSpecies} = scalar( keys %species_unique );

  #----------------------------------------

  # number of interactions - not yet......
  # TODO need to properly calculate the number of interactions for a Pfam-B

  $summaryData{numInt} = 0;

  #----------------------------------------

  $c->stash->{summaryData} = \%summaryData;

}

#-------------------------------------------------------------------------------

=head2 get_db_xrefs : Private

Retrieves database cross-references.

=cut

sub get_db_xrefs : Private {
  my ( $this, $c ) = @_;

  # get just the row from the prodom table, used to get hold of the ADDA link
  $c->stash->{adda} = $c->model('PfamDB::PfambDatabaseLinks')
                        ->find( { auto_pfamb => $c->stash->{pfam}->auto_pfamb,
                                  db_id      => 'ADDA' } );

  # cross references
  my %xRefs;

  # stuff in the accession and ID for this entry
  $xRefs{entryAcc} = $c->stash->{pfam}->pfamb_acc;
  $xRefs{entryId}  = $c->stash->{pfam}->pfamb_id;

  # TODO get rid of references to PRODOM and add ADDA links

  # PfamB to PfamA links based on PRODOM
  my %btoaPRODOM;
  foreach my $xref ( $c->stash->{pfam}->pfamb_database_links ) {
    if ( $xref->db_id eq 'PFAMA_PRODOM' ) {
      $btoaPRODOM{$xref->db_link} = $xref;
    }
    else {
      push @{ $xRefs{$xref->db_id} }, $xref;
    }
  }

  # PfamB to PfamB links based on PRC
  my @btobPRC = $c->model('PfamDB::Pfamb2pfambPrcResults')
                  ->search( { 'pfamB1.pfamb_acc' => $c->stash->{pfam}->pfamb_acc },
                            { join               => [ qw( pfamB1 pfamB2 ) ],
                              select             => [ qw( pfamB1.pfamb_acc 
                                                          pfamB2.pfamb_acc evalue ) ],
                              as                 => [ qw( l_pfamb_acc 
                                                          r_pfamb_acc 
                                                          evalue ) ],
                              order_by           => 'pfamB2.auto_pfamb ASC' } );

  $xRefs{btobPRC} = [];
  foreach ( @btobPRC ) {
    next if $_->get_column( 'evalue' ) <= 0.001;
    next if $_->get_column( 'l_pfamb_acc') eq $_->get_column( 'r_pfamb_acc' );
    push @{$xRefs{btobPRC}}, $_;
  }

#  $xRefs{btobPRC} = \@btobPRC if scalar @btobPRC;

  # PfamB to PfamA links based on PRC
  my @btoaPRC = $c->model('PfamDB::Pfamb2pfamaPrcResults')
                  ->search( { 'pfamB.pfamb_acc' => $c->stash->{pfam}->pfamb_acc, },
                            { prefetch  => [ qw( pfamA pfamB ) ] } );

  # find the union between PRC and PRODOM PfamB links
  my %btoaPRC;
  foreach ( @btoaPRC ) {
    $btoaPRC{$_->pfamB_acc} = $_ if $_->evalue <= 0.001;
  }

  my %btoaBOTH;
  foreach ( keys %btoaPRC, keys %btoaPRODOM ) {
    $btoaBOTH{$_} = $btoaPRC{$_}
      if ( exists( $btoaPRC{$_} ) and exists( $btoaPRODOM{$_} ) );
  }

  # and then prune out those accessions that are in both lists
  foreach ( keys %btoaPRC ) {
    delete $btoaPRC{$_} if exists $btoaBOTH{$_};
  }
  foreach ( keys %btoaPRODOM ) {
    delete $btoaPRODOM{$_} if exists $btoaBOTH{$_};
  }

  # now populate the hash of xRefs;
  my @btoaPRC_pruned;
  foreach ( sort keys %btoaPRC ) {
    push @btoaPRC_pruned, $btoaPRC{$_};
  }
  $xRefs{btoaPRC} = \@btoaPRC_pruned if scalar @btoaPRC_pruned;

  my @btoaPRODOM;
  foreach ( sort keys %btoaPRODOM ) {
    push @btoaPRODOM, $btoaPRODOM{$_};
  }
  $xRefs{btoaPRODOM} = \@btoaPRODOM if scalar @btoaPRODOM;

  my @btoaBOTH;
  foreach ( sort keys %btoaBOTH ) {
    push @btoaBOTH, $btoaBOTH{$_};
  }
  $xRefs{btoaBOTH} = \@btoaBOTH if scalar @btoaBOTH;

  $c->stash->{xrefs} = \%xRefs;
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk)

This is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.

=cut

1;
