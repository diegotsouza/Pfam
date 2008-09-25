package RfamDB::RfamKeywords;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("rfam_keywords");
__PACKAGE__->add_columns(
  "auto_rfam_keywords",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "rfam_acc",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 7 },
  "rfam_id",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 40 },
  "description",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "rfam_general",
  {
    data_type => "LONGTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 4294967295,
  },
  "literature",
  {
    data_type => "LONGTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 4294967295,
  },
  "wiki",
  {
    data_type => "LONGTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 4294967295,
  },
);
__PACKAGE__->set_primary_key("auto_rfam_keywords");


# Created by DBIx::Class::Schema::Loader v0.04004 @ 2008-09-25 21:50:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:16iIXdWqd1LLY+oqscY1kw


#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>
Rob Finn, C<rdf@sanger.ac.uk>
Paul Gardner, C<pg5@sanger.ac.uk>
Jennifer Daub, C<jd7@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk),
         Paul Gardner, C<pg5@sanger.ac.uk>, Jennifer Daub, C<jd7@sanger.ac.uk>

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
