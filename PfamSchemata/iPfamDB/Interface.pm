package iPfamDB::Interface;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("interface");
__PACKAGE__->add_columns(
  "structure_accession",
  { data_type => "INT", default_value => "", is_nullable => 0, size => 10 },
  "chain_a",
  { data_type => "CHAR", default_value => "", is_nullable => 0, size => 1 },
  "chain_b",
  { data_type => "CHAR", default_value => "", is_nullable => 0, size => 1 },
  "residue_a",
  { data_type => "INT", default_value => "", is_nullable => 0, size => 11 },
  "residue_b",
  { data_type => "INT", default_value => "", is_nullable => 0, size => 11 },
  "bond",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 6 },
);


# Created by DBIx::Class::Schema::Loader v0.04003 @ 2007-10-26 10:08:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2gal6hbgFq23JZ5WJGztuA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
