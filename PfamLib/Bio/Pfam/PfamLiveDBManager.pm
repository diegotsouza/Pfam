
#
# BioPerl module for Bio::Pfam::PfamLiveDBManager
#
# $Author: jt6 $

package Bio::Pfam::PfamLiveDBManager;

use Data::Dumper;
use Carp qw(cluck croak carp);

use base Bio::Pfam::PfamDBManager;
use PfamLive;
use strict;
use warnings;

sub new {
 print "In PfamLive new\n\n";
    my $caller = shift;
    my $class = ref($caller) || $caller;
    my %dbiParams = ();
    my $self = { user      => "pfamro",
		 host      => "pfam",
		 port      => "3306",
		 database  => "pfamlive",
		 driver    => "mysql",
		 @_,};

    carp("The new object contains :".Dumper($self)) if($self->{'debug'});
    eval{
     $self->{'schema'} = PfamLive->connect("dbi".
				       ":".$self->{driver}.
				       ":".$self->{database}.
				       ":".$self->{host}.
				       ":".$self->{port},
				       $self->{user},
				       $self->{password},
				       \%dbiParams);
    };
    if($@){
      croak("Failed to get schema for databse:".$self->{'database'}.". Error:[$@]\n");     
    }
    return bless($self, $caller);
} 

#
# Select methods specific to Pfamlive should go in here.
#

sub getClanLockData{
  my ($self, $clan) = @_;
  
  my $lockData;
  if($clan =~ /CL\d{4}/){
    $lockData = $self->getSchema
                  ->resultset("Clan_locks")
                    ->find({"clans.clan_acc" => $clan},
                      { join                 => [ qw/clans/],
                        prefetch             => [ qw/clans/] });   
  }elsif($clan =~ /\S{1,16}/){
    $self->getSchema
          ->resultset
            ->find({"clans.clan_id" => $clan},
                   { join           => [ qw/clans/],
                     prefetch       => [ qw/clans/] });
  }else{
    croak("$clan does not look like a clan accession or identifer\n");
  }
  
  return $lockData if(ref($lockData));
}


#
# Specific insert/update methods should go here
#
sub updateClanMembership{
  my ($self, $autoClan, $autoPfamA) = @_;
  my ($result);
  carp("Updating clan membership with auto_clan: $autoClan, auto_pfamA: $autoPfamA") if($self->{'debug'});
  if($autoClan && $autoPfamA){  
     $result = $self->getSchema
                        ->resultset('Clan_membership')
                          ->create({ auto_clan  => $autoClan,
                                     auto_pfamA => $autoPfamA});
  }else{
    cluck("Can not update clan_membership without both auto_pfamA and auto_clan!")
  }
  return($result); 
 }

sub removeFamilyFromClanMembership {
  my ($self, $autoClan, $autoPfamA) = @_;
  my ($result);
  carp("Removing family from clan membership: $autoClan, auto_pfamA: $autoPfamA") if($self->{'debug'});
  if($autoClan && $autoPfamA){  
     $result = $self->getSchema
                      ->resultset('Clan_membership')
                          ->find({ auto_clan  => $autoClan,
                                   auto_pfamA => $autoPfamA})->delete;
                                  
                                   print STDERR "\n\n****** $result ******\n\n" if($result->isa("DBIx::Class::Row"));
  }else{
    cluck("Can not remove family from clan_membership without both auto_pfamA and auto_clan!")
  }
  return($result);
}

sub removeClan {
  my ($self, $autoClan) = @_;
  
  my $result; 
  if($autoClan){  
     $result = $self->getSchema
                      ->resultset('Clans')
                          ->find({ auto_clan  => $autoClan})->delete;
  }else{
    cluck("Can not remove family from clan_membership without both auto_pfamA and auto_clan!")
  }
  return($result);
}
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



