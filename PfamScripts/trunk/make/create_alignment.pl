#!/usr/local/bin/perl

use IO::File;
use Getopt::Long;
use strict;
use Bio::Pfam::AlignMethods;

my $prog = $0;

my ($fasta_file, $t_coffee, $mafft, $clustalw, $probcons, $mask, $muscle, $musclep, $method, $pdb, $chain, $mcount);

&GetOptions('fasta=s' => \$fasta_file,
            't!' => \$t_coffee,
	    'm!' => \$mafft,	    
	    'cl!' => \$clustalw,
	    'p!'  => \$probcons,
            'ma!' => \$mask,
	    'mu!' => \$muscle,
	    'mup!'=> \$musclep,        
            'pdb=s' => \$pdb,
            'chain=s' => \$chain,
            );

if($t_coffee) {
  $method = "t_coffee";
  $mcount++;
}
if($mafft) {
  $method = "mafft";
  $mcount++;
}
if($clustalw) {
  $method = "clustalw";
  $mcount++;
}
if($probcons) {
  $method = "probcons";
  $mcount++;
}
if($mask) {
  $method = "mask";
  $mcount++;
  if(!$pdb) {
      &AlignMethods::help($prog);
  }
}
if($muscle) {
  $method = "muscle";  
  $mcount++;
}
if($musclep) {
  $method = "musclep";
  $mcount++;
}
if($mcount == 0) {
  &AlignMethods::help($prog);
}


if($mcount !=1) {
    die "More than one alignment method selected!\n";
}



if (!$fasta_file) {
  &AlignMethods::help($prog);
}
if(! -s $fasta_file) {
  die "Your fasta file either does not exist or is of zero size\n";
}

#Remove // from end of file if it exists
system("grep -v \"^//\" $fasta_file > tmp.$$");
if(-s "tmp.$$") {
  unlink $fasta_file;
  rename ("tmp.$$", $fasta_file );
}
else {
  die "Could not remove // from end of file\n";
} 

# Read fasta file and put ref into scalars
my @foo = &AlignMethods::read_fasta($fasta_file);
my @sequence    = @{shift @foo};
my @description = @{shift @foo};


# Create alignment 
my %hash=&AlignMethods::create_alignment(\@sequence,\@description,$method,$fasta_file,$pdb,$chain);


#Print alignment
&AlignMethods::print_alignment(\%hash, $method);



 
