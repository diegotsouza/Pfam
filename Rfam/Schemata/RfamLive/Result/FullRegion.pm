use utf8;
package RfamLive::Result::FullRegion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

RfamLive::Result::FullRegion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<full_region>

=cut

__PACKAGE__->table("full_region");

=head1 ACCESSORS

=head2 rfam_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 rfamseq_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 13

=head2 auto_genome

  data_type: 'integer'
  is_nullable: 1

=head2 seq_start

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 seq_end

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 bit_score

  data_type: 'double precision'
  default_value: 0.00
  is_nullable: 0
  size: [7,2]

99999.99 is the approx limit from Infernal.

=head2 evalue_score

  data_type: 'varchar'
  default_value: 0
  is_nullable: 0
  size: 15

=head2 type

  data_type: 'enum'
  default_value: 'full'
  extra: {list => ["seed","full"]}
  is_nullable: 1

=head2 genome_start

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 genome_end

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 sequence

  accessor: undef
  data_type: 'longtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "rfam_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "rfamseq_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 13 },
  "auto_genome",
  { data_type => "integer", is_nullable => 1 },
  "seq_start",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "seq_end",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "bit_score",
  {
    data_type => "double precision",
    default_value => "0.00",
    is_nullable => 0,
    size => [7, 2],
  },
  "evalue_score",
  { data_type => "varchar", default_value => 0, is_nullable => 0, size => 15 },
  "type",
  {
    data_type => "enum",
    default_value => "full",
    extra => { list => ["seed", "full"] },
    is_nullable => 1,
  },
  "genome_start",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "genome_end",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "sequence",
  { accessor => undef, data_type => "longtext", is_nullable => 1 },
);

=head1 RELATIONS

=head2 rfam_acc

Type: belongs_to

Related object: L<RfamLive::Result::Family>

=cut

__PACKAGE__->belongs_to(
  "rfam_acc",
  "RfamLive::Result::Family",
  { rfam_acc => "rfam_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 rfamseq_acc

Type: belongs_to

Related object: L<RfamLive::Result::Rfamseq>

=cut

__PACKAGE__->belongs_to(
  "rfamseq_acc",
  "RfamLive::Result::Rfamseq",
  { rfamseq_acc => "rfamseq_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-01-23 13:50:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZhPJ+FCMbLi7OFEH6Zkp7Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;