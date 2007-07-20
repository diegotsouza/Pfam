
# GetHMM.pm
# jt6 20061003 WTSI
#
# $Id: GetHMM.pm,v 1.7 2007-07-20 10:58:06 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Family::GetHMM - retrieve an HMM

=cut

package PfamWeb::Controller::Family::GetHMM;

=head1 DESCRIPTION

Retrieves the raw HMM for a specified Pfam family.

Generates a B<text file>.

$Id: GetHMM.pm,v 1.7 2007-07-20 10:58:06 jt6 Exp $

=cut

use strict;
use warnings;

use base 'PfamWeb::Controller::Family';

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 getHMM : Private

Serve the contents of the HMM for a Pfam-A entry from the database. Requires 
the "mode" parameter to be set either to "ls" or "fs".

=cut

sub getHMM : Path {
  my( $this, $c ) = @_;

  return unless defined $c->stash->{pfam};

  # find out which HMM we want...
  my( $mode ) = $c->req->param( 'mode' ) =~ /^(fs|ls)$/;
  if( not defined $mode ) {
    $c->stash->{errorMsg} = 'There was no HMM type specified. '
                            . '&quot;mode&quot; should be either "ls" or "fs"';
    return;
  }

  # retrieve the HMM from the appropriate table
  my $hmm;
  if( $mode eq 'ls' ) {
    my $rs = $c->model('PfamDB::PfamA_HMM_ls')
               ->find( { auto_pfamA => $c->stash->{pfam}->auto_pfamA } );

    unless( $rs ) {
      $c->stash->{errorMsg} = "We could not find the &quot;ls&quot; HMM file for " 
                              . $c->stash->{acc};
      return;
    }

    $hmm = $rs->hmm_ls;

  } elsif( $mode eq 'fs' ) {
    my $rs = $c->model('PfamDB::PfamA_HMM_fs')
               ->find( { auto_pfamA => $c->stash->{pfam}->auto_pfamA } );

    unless( $rs ) {
      $c->stash->{errorMsg} = "We could not find the &quot;fs&quot; HMM file for " 
                              . $c->stash->{acc};
      return;
    }    

    $hmm = $rs->hmm_fs;
  }  

  unless( $hmm ) {
    $c->stash->{errorMsg} = "We could not find the $mode HMM file for " 
                            . $c->stash->{acc};
    return;
  }    

  my $filename = $c->stash->{pfam}->pfamA_id."_$mode.hmm";

  # set the response headers
  $c->res->content_type( 'text/plain' );
  #$c->res->headers->header( 'Content-disposition' => "attachment; filename=$filename" );

  # at this point we should have the HMM in hand, so spit it out to the 
  # response and we're done
  $c->res->body( $hmm );

  # the RenderView action on the end method in Section.pm will spot that there's
  # content in the response and return without trying to render any templates
}

#-------------------------------------------------------------------------------

=head2 getHMMFromFile : Private

Serve the contents of the HMM file for a Pfam-A entry. Requires the "mode"
parameter to be set either to ls" or "fs". This should now be redundant, but
it's here for sentimental reasons...

=cut

sub getHMMFromFile : Local {
  my( $this, $c ) = @_;

  return unless defined $c->stash->{pfam};

  # find out which file we want...
  my( $mode ) = $c->req->param( 'mode' ) =~ /^(fs|ls)$/;
  if( not defined $mode ) {
    $c->stash->{errorMsg} = 'There was no HMM type specified. '
                            . '&quot;mode&quot; should be either "ls" or "fs"';
    return;
  }

  # the file
  $c->stash->{HMMFile} = $this->{HMMFileDir} . "/$mode/" . $c->stash->{acc};
  $c->log->debug( 'Family::getHMMFromFile: looking for HMM file |'
                  . $c->stash->{HMMFile} . '|' );

  unless( open( HMM, $c->stash->{HMMFile} ) ) {
    $c->stash->{errorMsg} = "We could not find the $mode HMM file for " 
                            . $c->stash->{acc};
    return;
  }    

  # set the response headers
  $c->res->content_type( 'text/plain' );
  $c->res->headers->header( 'Content-disposition' => 'attachment; filename='
                                                     . $c->stash->{pfam}->pfamA_id.'.hmm' );

  # at this point we should have the HMM file open, so suck it in and spit it
  # out to the response
  while( <HMM> ) { $c->res->write( $_ ) };

  # the RenderView action on the end method in Section.pm will spot that there's
  # content in the response and return without trying to render any templates
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk)

This is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
or see the on-line version at http://www.gnu.org/copyleft/gpl.txt

=cut

1;
