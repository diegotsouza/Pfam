package DfamLive::Schema::Result::DfamRegSeed;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

DfamLive::Schema::Result::DfamRegSeed

=cut

__PACKAGE__->table("dfam_reg_seed");

=head1 ACCESSORS

=head2 dfam_acc

  data_type: 'varchar'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 auto_dfamseq

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 seq_start

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 seq_end

  data_type: 'mediumint'
  is_nullable: 0

=head2 cigar

  data_type: 'text'
  is_nullable: 1

=head2 tree_order

  data_type: 'mediumint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "dfam_acc",
  {
    data_type => "varchar",
    default_value => 0,
    is_foreign_key => 1,
    is_nullable => 0,
    size => 7,
  },
  "auto_dfamseq",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "seq_start",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "seq_end",
  { data_type => "mediumint", is_nullable => 0 },
  "cigar",
  { data_type => "text", is_nullable => 1 },
  "tree_order",
  { data_type => "mediumint", is_nullable => 1 },
);
__PACKAGE__->add_unique_constraint(
  "dfam_reg_seed_reg_idx",
  ["dfam_acc", "auto_dfamseq", "seq_start", "seq_end"],
);

=head1 RELATIONS

=head2 dfam_acc

Type: belongs_to

Related object: L<DfamLive::Schema::Result::Dfam>

=cut

__PACKAGE__->belongs_to(
  "dfam_acc",
  "DfamLive::Schema::Result::Dfam",
  { dfam_acc => "dfam_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 auto_dfamseq

Type: belongs_to

Related object: L<DfamLive::Schema::Result::Dfamseq>

=cut

__PACKAGE__->belongs_to(
  "auto_dfamseq",
  "DfamLive::Schema::Result::Dfamseq",
  { auto_dfamseq => "auto_dfamseq" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-13 22:18:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jQfaYUVmkyije2OwUWtkwg
# These lines were loaded from '/opt/dfam/code/Schemata/DfamLive/Schema/Result/DfamRegSeed.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

package DfamLive::Schema::Result::DfamRegSeed;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

DfamLive::Schema::Result::DfamRegSeed

=cut

__PACKAGE__->table("dfam_reg_seed");

=head1 ACCESSORS

=head2 dfam_acc

  data_type: 'varchar'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 auto_dfamseq

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 seq_start

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 seq_end

  data_type: 'mediumint'
  is_nullable: 0

=head2 cigar

  data_type: 'text'
  is_nullable: 1

=head2 tree_order

  data_type: 'mediumint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "dfam_acc",
  {
    data_type => "varchar",
    default_value => 0,
    is_foreign_key => 1,
    is_nullable => 0,
    size => 7,
  },
  "auto_dfamseq",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "seq_start",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "seq_end",
  { data_type => "mediumint", is_nullable => 0 },
  "cigar",
  { data_type => "text", is_nullable => 1 },
  "tree_order",
  { data_type => "mediumint", is_nullable => 1 },
);
__PACKAGE__->add_unique_constraint(
  "dfam_reg_seed_reg_idx",
  ["dfam_acc", "auto_dfamseq", "seq_start", "seq_end"],
);

=head1 RELATIONS

=head2 dfam_acc

Type: belongs_to

Related object: L<DfamLive::Schema::Result::Dfam>

=cut

__PACKAGE__->belongs_to(
  "dfam_acc",
  "DfamLive::Schema::Result::Dfam",
  { dfam_acc => "dfam_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 auto_dfamseq

Type: belongs_to

Related object: L<DfamLive::Schema::Result::Dfamseq>

=cut

__PACKAGE__->belongs_to(
  "auto_dfamseq",
  "DfamLive::Schema::Result::Dfamseq",
  { auto_dfamseq => "auto_dfamseq" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-13 22:12:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qQY+dHZnZn8fHXCNx6KPjA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
# End of lines loaded from '/opt/dfam/code/Schemata/DfamLive/Schema/Result/DfamRegSeed.pm' 


# You can replace this text with custom content, and it will be preserved on regeneration
1;
