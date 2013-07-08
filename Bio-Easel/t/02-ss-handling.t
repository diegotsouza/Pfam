use strict;
use warnings FATAL => 'all';
use Test::More tests => 6;

BEGIN {
    use_ok( 'Bio::Easel::MSA' ) || print "Bail out!\n";
}

# test new 
my $alnfile = "./t/data/test.sto";
my $msa = Bio::Easel::MSA->new({
   fileLocation => $alnfile, 
});
isa_ok($msa, "Bio::Easel::MSA");

# test has_ss_cons
my $has_ss_cons = $msa->has_ss_cons;
is($has_ss_cons, 1);

# test get_ss_cons
my $ss_cons = $msa->get_ss_cons;
is($ss_cons, ".::<<<____>->>:<<-<.___.>>>.");

# test calc_and_write_bp_stats
#TODO: make this into a test somehow
my $outfile = "./t/data/test-msa-bp.out";

my $acc = "RFXXXXX";
$msa->set_accession($acc);
is($msa->get_accession, $acc);

my $name = "myRNA";
$msa->set_name($name);
is($msa->get_name, $name);

$msa->calc_and_write_bp_stats($outfile);

#unlink $outfile
