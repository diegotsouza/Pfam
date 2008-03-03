package iPfamDB::ProteinIntAtoms;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("protein_int_atoms");
__PACKAGE__->add_columns(
  "protein_acc",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "atom_number",
  { data_type => "INT", default_value => "", is_nullable => 0, size => 10 },
  "protein_id",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "residue",
  { data_type => "INT", default_value => "", is_nullable => 0, size => 11 },
  "atom_acc",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "atom",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 3 },
);
__PACKAGE__->set_primary_key("atom_acc");


# Created by DBIx::Class::Schema::Loader v0.04003 @ 2008-02-26 14:01:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sNYXDXh5GeO5rW8LOrRNXA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->add_unique_constraint(
    intAtomsConst => [ qw(protein_acc residue atom_number) ],
);
1;
