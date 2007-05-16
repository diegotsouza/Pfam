
# DownloadAlignment.pm
# rdf 20061005 WTSI
#
# $Id: DownloadAlignment.pm,v 1.8 2007-05-16 13:57:43 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Family::DownloadAlignment - controller to
serve up alignments in various formats

=cut

package PfamWeb::Controller::Family::DownloadAlignment;

=head1 DESCRIPTION

Generates a B<full page>.

$Id: DownloadAlignment.pm,v 1.8 2007-05-16 13:57:43 jt6 Exp $

=cut

use strict;
use warnings;

use Compress::Zlib;

use base "PfamWeb::Controller::Family";

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 auto : Private

Just decides whether we're dealing with a seed or full alignment.

=cut

sub auto : Private {
  my( $this, $c ) = @_;
  
  if( defined $c->req->param( "alnType" ) ) {
    $c->stash->{alnType} = ( $c->req->param( "alnType" ) eq "seed" ) ? "seed" : "full";
    $c->log->debug( "DownloadAlignment::auto: setting alnType to |" . 
                    $c->stash->{alnType} . "|" );
  } else {
    $c->stash->{alnType} = "seed";
    $c->log->debug( "DownloadAlignment::auto: no alnType parameter; defaulting to seed " );
  }
  
}

#-------------------------------------------------------------------------------

=head2 downloadAlignment : Path

A simple action to redirect to the static HTML file on disk, chosen according
to the form parameters, i.e. seed or full alignment.

=cut

sub downloadAlignment : Path( "/family/downloadalignment" ) {
  my( $this, $c ) = @_;

  my $url;
  if( $c->stash->{alnType} eq "seed" ) {
    $url = "http://www.sanger.ac.uk/Software/Pfam/data/jtml/seed/"
           . $c->stash->{acc} . ".shtml";
  } else {
    $url = "http://www.sanger.ac.uk/Software/Pfam/data/jtml/full/"
           . $c->stash->{acc} . ".shtml";
  }
  
  $c->log->debug( "DownloadAlignment::downloadAlignment: redirecting to |$url|" );
  $c->res->redirect( $url );

}

#-------------------------------------------------------------------------------

=head2 downloadGzippedAlignment : Path

This is a version of the "downloadalignment" action that expects to find the 
alignment files on disk already gzipped. As such, it's going to be disappointed
these days... (20070503)

=cut

sub downloadGzippedAlignment : Path( "/family/downloadgzippedalignment" ) {
  my( $this, $c ) = @_;

  if( $c->req->header( "Accept-Encoding" ) and
    $c->req->header( "Accept-Encoding" ) =~ /gzip/ ) {
  
    $c->log->debug( "DownloadAlignment::downloadGzippedAlignment: browser accepts gzipped content" );
  
    my $url;
    if( $c->req->param( "alnType" ) eq "seed" ) {
      $url = "http://www.sanger.ac.uk/Software/Pfam/data/jtml/seed/"
             . $c->stash->{acc} . ".shtml.gz";
    } else {
      $url = "http://www.sanger.ac.uk/Software/Pfam/data/jtml/full/"
             . $c->stash->{acc} . ".shtml.gz";
    }
  
    $c->log->debug( "DownloadAlignment::downloadGzippedAlignment: redirecting to |$url|" );
    $c->res->redirect( $url );
    return;

  } else {
  
    $c->log->debug( "DownloadAlignment::downloadGzippedAlignment: browser doesn't accept gzipped content" );
  
    my $file;
    if( $c->req->param( "alnType" ) eq "seed" ) {
      $file = $this->{alnFileDir} . "/jtml/seed/" . $c->stash->{acc} . ".shtml.gz";
    } else {
      # must want the full alignment
      $file = $this->{alnFileDir} . "/jtml/full/" . $c->stash->{acc} . ".shtml.gz";
    }
  
    $c->log->debug( "DownloadAlignment::downloadGzippedAlignment: retrieving alignment from |$file|" );
  
    $c->stash->{contentType} = "text/html";
    $c->stash->{output} = $c->forward( "getAlignmentFile", [ $file ] );
  }

}

#-------------------------------------------------------------------------------

=head2 formatAlignment : Path

Serves the plain text (no markup) alignment. Also applies various
changes to the alignment before hand, such as changing the gap style
or sequence order.

By default this method will generate Stockholm format, but the
following formats are also available and can be specified with the
C<format> parameter:

=over

=item * pfam

Essentially Stockholm with markup lines removed

=item * fasta

Vanilla FASTA format

=item * msf

No idea...

=item * stockholm (default)

Standard Stockholm format

=back

The exact styles (other than C<pfam>) are defined by BioPerl.

=cut

sub formatAlignment : Path( "/family/formatalignment" ) {
  my( $this, $c ) = @_;

  my $alignment;

  # see what type of family we have, A or B
  if ( $c->stash->{entryType} eq "A" ) {

    my $file = $this->{alnFileDir} . "/" . $c->stash->{alnType} . "/" . 
               $c->stash->{acc} . ".full.gz";
    $c->log->debug( "DownloadAlignment::formatAlignment: trying to load |$file|" );
  
    # make sure that we've built a path to a real file...
    unless( -f $file ) {
      $c->log->warn( "DownloadAlignment::formatAlignment: can't find file \"$file\"" );
      return;
    }
  
    # get hold of the alignment
    $alignment = $c->forward( "getAlignmentFile", [ $file ] );

  } elsif ( $c->stash->{entryType} eq "B" ) {
    $alignment = $c->forward( "getAlignmentDB" );
  }

  my $pfamaln = new Bio::Pfam::AlignPfam->new;
  eval {
    $pfamaln->read_stockholm( $alignment );
  };
  if($@){
    $pfamaln->throw("Error reading stockholm file:[$@]");
  };

  # gaps param can be default, dashes, dot or none
  if( $c->req->param("gaps") ) {
    if( $c->req->param("gaps") eq "none" ) {
      $pfamaln->map_chars('-', '');
      $pfamaln->map_chars('\.', '');
    } elsif( $c->req->param("gaps") eq "dots" ) {
      $pfamaln->map_chars('-', '.');
    } elsif( $c->req->param("gaps") eq "dashes" ) {
      $pfamaln->map_chars('\.', '-');
    }
  }

  # case param can be u or l
  if( $c->req->param("case") and $c->req->param("case") eq "u" ) {
    $pfamaln->uppercase;
  }

  # order param can be tree or alphabetical
  if( $c->req->param("order") and $c->req->param("order") eq "alpha" ) {
    $pfamaln->sort_alphabetically;
  }

  # format param can be one of pfam, stockholm, fasta or MSF
  my $output;
  if( $c->req->param( "format" ) ) {
    if( $c->req->param( "format" ) eq "pfam" ) {
      $output = $pfamaln->write_Pfam;
    } elsif( $c->req->param( "format" ) eq "fasta" ) {
      $output = $pfamaln->write_fasta;
    } elsif( $c->req->param( "format" ) eq "msf" ) {
      $output = $pfamaln->write_MSF;
    } else {
      # stockholm and "anything else"
      $output = $pfamaln->write_stockholm;
    }
  }

  $c->stash->{output} = $output;
}

#-------------------------------------------------------------------------------

=head2 getAlignmentFile : Private

Reads a gzipped alignment file from disk and returns it as an array reference.

=cut

sub getAlignmentFile : Private {
  my( $this, $c, $file ) = @_;

  my $gz = gzopen( $file, "rb" )
  or die "Couldn't open alignment file \"$file\": $gzerrno";

  my( $input, $buffer );
  $input .= $buffer while $gz->gzread( $buffer ) > 0;
  my @input = split /\n/, $input;

  die "Error reading from alignment file \"$file\": $gzerrno" . ( $gzerrno+0)
  unless $gzerrno == Z_STREAM_END;

  $gz->gzclose;

  return \@input;
}

#-------------------------------------------------------------------------------

=head2 getAlignmentDB : Private

Reads a (butchered) Stockholm-format alignment file from the database
and returns it as an array reference. The only alignments that are
stored in the DB are for B<PfamB> families.

=cut

sub getAlignmentDB : Private {
  my( $this, $c ) = @_;

  # need to tack on a header and a footer line before it's really
  # Stockholm-format... go figure
  my @aln = split /\n/, 
                  "# STOCKHOLM 1.0\n"
                  . $c->stash->{pfam}->pfamB_stockholm->stockholm_data . "//\n";

  return \@aln;
}

#-------------------------------------------------------------------------------

=head2 end : Private

Writes the sequence alignment directly to the response object.

=cut

sub end : Private {
  my( $this, $c ) = @_;

  # set the content type either according to what the caller gave us,
  # or default to plain text
  $c->res->content_type( $c->stash->{contentType} ? $c->stash->{contentType} : "text/plain" );

  # are we downloading this or just dumping it to the browser ?
  if( $c->req->param( "download" ) ) {
  
    # figure out the filename
    my $filename;
    if( $c->stash->{entryType} eq "A" ) {
      $filename = $c->stash->{acc} . "_" . $c->stash->{alnType}. ".txt";
    } else {
      # don't bother sticking "seed" or "full" in there if it's a PfamB
      $filename = $c->stash->{acc} . ".txt";
    }  
  
    $c->res->headers->header( "Content-disposition" => "attachment; filename=$filename" );
  }

  foreach ( @{$c->stash->{output}} ) {
    $c->res->write( $_ );
  }

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
