#! /software/bin/perl -w

# A program to take "good" sequences from the Rfam full ALIGN, adding them to the SEED using the CM, producing a SEED.new file. 

use strict;
use Rfam;
use Rfam::RfamAlign;
use Getopt::Long;
use Log::Log4perl qw(get_logger :levels); #Damn Ben! 
use DBI;

my $minpid=0.6;
my $maxpid=0.95;
my $nucends=5;
my $bpconsistency=0.75;
my $forbidden=1;
my $info=1;

my @forbidden_terms = qw(
repeat
repetitive
pseudogene
pseudo-gene
transpos
);

# MySQL connection details.
my $database = $Rfam::embl;
my $host     = "cbi3";
my $user     = "genero";

# Query to search for the accession and description of embl entries with the embl id
my $query = qq(
           select entry.accession_version, description.description
           from entry, description
           where entry.accession_version=?
           and entry.entry_id=description.entry_id;
   );

#Global variable for the "is_complementary" function - saves reinitialising each time:
my %canonical_basepair = (
    AU => 1,
    AT => 1,
    UA => 1,
    TA => 1,
    CG => 1,
    GC => 1,
    UG => 1,
    GU => 1,
    TG => 1,
    GT => 1,
    RY => 1,
    YR => 1,
    MK => 1,
    KM => 1,
    SS => 1,
    WW => 1
    );

my (@required_terms, @extra_forbidden_terms, $help);

&GetOptions("minpid=s"         => \$minpid,
            "maxpid=s"         => \$maxpid,
	    "nucends=s"        => \$nucends,
	    "bpcons=s"         => \$bpconsistency,
	    "required=s@"      => \@required_terms,
	    "forbidden!"       => \$forbidden,
	    "extraforbidden=s@"=> \@extra_forbidden_terms,
	    "info!"            => \$info,
	    "h|help"           => \$help
    );

if( $help ) {
    &help();
    exit(1);
}

if (@extra_forbidden_terms){
    push(@forbidden_terms, @extra_forbidden_terms);
}

############Ben's Logging Crap:#############
######
# Get a logger
######
my $logger = get_logger();

$logger->level($DEBUG) if $info;

######
# Explicitly set the logging style and output; this seems damned ridiculous, aren't the defaults sensible?
######
BEGIN {
    # We initialise on the fly
        Log::Log4perl->init( \<<EOF
log4perl.rootLogger=ERROR, SCREEN
log4perl.appender.SCREEN=Log::Log4perl::Appender::Screen
log4perl.appender.SCREEN.mode=append
log4perl.appender.SCREEN.layout=PatternLayout
#log4perl.appender.SCREEN.layout.ConversionPattern=%d %p> %F{1} on %H line %L: %M - %m%n
EOF
        );
}
############Ben's Logging Crap Ends#########

#READ SEED:
open( SEED, "SEED" ) or $logger->logdie("FATAL: Couldn't open SEED\n [$!]");
my $seed = new Rfam::RfamAlign;
$seed -> read_stockholm( \*SEED );
close(SEED);

my (%SEEDhash, %SEEDseqs, %SEEDstarts, %SEEDends); #

#Read SEED into hashes. This maybe daft. Could use "$seed" directly. But then we lose the niceties of hashes. Rewrite "read_stockholm()"?:
foreach my $seqobj ( $seed->each_seq() ) {
    my $longseqname = $seqobj->id . "/" . $seqobj->start . "-" . $seqobj->end;
    $SEEDhash{$longseqname}= 1;
    push( @{ $SEEDstarts{$seqobj->id} }, $seqobj->start );
    push( @{ $SEEDends{$seqobj->id} }, $seqobj->end );
}

#READ ALIGN:
open( ALIGN, "ALIGN" ) or die ("FATAL: Couldn't open ALIGN [$!]\n $!\n");
my $align = new Rfam::RfamAlign;
$align -> read_stockholm( \*ALIGN );
close(ALIGN);
my @alignlist = $align->each_seq();
my $ss_cons = $align->ss_cons->getInfernalString(); #This is damned confusing!

#Make a pair table from the secondary structure & initialise basepair hash:
my @table = make_pair_table($ss_cons);
my %basepairs;
my $noseqs = scalar(@alignlist);
my $len = $table[0];
my $nopairs = 0;
for( my $i = 1; $i<$len+1; $i++ ){
    next unless $table[$i];
    
    my $j = $table[$i];
    if ($i<$j){
	my $bpstr = "$i:$j";
	$basepairs{$bpstr} = 0;
	$nopairs++;
    }
}

my $alignlength = length($alignlist[0]->seq);
my (%ALIGNhash, %ALIGNandSEEDhash
, %ALIGNnames); #array of hashes to store nuc-counts.

#Read ALIGN info into hashes and test for overlaps with SEED:
foreach my $seqobj ( @alignlist ) {

    my $start = $seqobj->start;
    my $end = $seqobj->end;
    my $longseqname = $seqobj->id . "/" . $start . "-" . $end;

    $ALIGNhash{$longseqname}=uc($seqobj->seq); #A hash of arrays might be more efficient. Saves all the splitting, substr's of length 1. 
    $ALIGNnames{$longseqname}=$seqobj->id;
    
    if (defined($SEEDhash{$longseqname})){
	$ALIGNandSEEDhash{$longseqname}=1;
    }
    elsif ( defined($SEEDstarts{$seqobj->id}) ) {
 	for (my $i=0; $i<scalar(@{ $SEEDends{$seqobj->id} }); $i++){
	    my $e = $SEEDends{$seqobj->id}[$i];
	    my $s = $SEEDstarts{$seqobj->id}[$i];
	    
	    if ($e<$s){
		my $tmp = $s;
		$s = $e;
		$e = $tmp;
	    }
	    
	    if ($end<$start){
		my $tmp = $start;
		$start = $end;
		$end = $tmp;
	    }
	    
	    if (overlap($start, $end, $s, $e)){
		$ALIGNandSEEDhash{$longseqname}=1;
	    }
	}
    }
}


# Create a connection to the database.
my $dbh = DBI->connect(
    "dbi:mysql:$database;$host", $user, "", {
	PrintError => 1, #Explicitly turn on DBI warn() and die() error reporting. 
	RaiseError => 1
}    );

# Prepare the query for execution.
my $sth = $dbh->prepare($query);
###########

my %timer_hash = (
    0 => 1,
    1 => 1,
    2 => 1,
    3 => 1,
    4 => 1,
    5 => 1,
    6 => 1,
    7 => 1,
    8 => 1,
    9 => 1
    );

#The big loop, locate sequences in align that fulfil our criteria and print to ALIGN2SEED:
open( OUT, ">ALIGN2SEED" ) or die ("FATAL: Couldn't open ALIGN2SEED [$!]\n $!\n");
my (%minpid, %maxpid, %ALIGN2SEEDcandidates);
my ($align2seedcount, $truncrejected, $structrejected, $pidrejected, $descforbidrejected, $descrequirerejected, $counter) = (0, 0, 0, 0, 0, 0, 0);

BIGLOOP: foreach my $longseqname (keys %ALIGNhash){
    
    if ($info){
	#Progress bar. Some thing to look at for the really long boring runs:
	$counter++;
	my $frac_done = int(10*$counter/$noseqs);
	if ($timer_hash{$frac_done}){
	    $timer_hash{$frac_done}=0;
	    printf "%d%% of ALIGN seqs tested\n", 10*$frac_done; #Use sprintf & logger or just printf? Bloody logger doesn't seem to do formatted output!
	}
    }
    
    #Sequence is not from SEED:
    if (!defined($ALIGNandSEEDhash{$longseqname})){
	$minpid{$longseqname}=1.0;
	$maxpid{$longseqname}=0.0;
	my ($ok,$oks,$oke,$persequence,$pidcounts) = (1,0,0,0.0,0);
	
	
	#Perform the fast and easy checks first, on the first fail goto next seq.
	
	#Check that the sequence ends are OK:

	for (my $i=0; $i<$nucends; $i++){
	    my $a= substr($ALIGNhash{$longseqname},$i,1);
	    
	    if (is_nucleotide($a)){
		$oks=1; 
	    }
	    my $b= substr($ALIGNhash{$longseqname},$alignlength-$i-1,1);
	    
	    if (is_nucleotide($b)){
		$oke=1;
	    }
	}
	
	if (!$oks || !$oke){
	    my $a= substr($ALIGNhash{$longseqname},0,$nucends);
	    my $b= substr($ALIGNhash{$longseqname},$alignlength-$nucends,$nucends);
	    $logger->info("REJECTED: $longseqname TRUNCATED!\t(start=$a, end=$b)\n");
	    $truncrejected++;
	    next BIGLOOP;
	}
	
	#Check structure consistency:
	my @seq = split(//,$ALIGNhash{$longseqname});
	if($nopairs>0){
	    foreach my $bpposns ( keys %basepairs ) {
		my @bpposns = split(/:/,$bpposns);
		my $ispair = is_complementary($seq[$bpposns[0]-1],$seq[$bpposns[1]-1]);
		$persequence += $ispair;
	    }
	    $persequence = $persequence/$nopairs;
	}
	else {
	    $persequence = 1.0;
	}
	
	if ($persequence<$bpconsistency){
	    if ($info){
		printf "REJECTED: $longseqname doesn't match the consensus structure (FCBP=%0.3f<thresh=$bpconsistency)!\n", $persequence; 
                #Logger still doesn't support formatted output! :-(
	    }
	    $structrejected++;
	    next BIGLOOP;
	}
	
	#Grab seq description, check it passes required & forbidden terms tests: 
	my $desc; 
	$sth->execute($ALIGNnames{$longseqname});
	my $res = $sth->fetchall_arrayref;
	foreach my $row (@$res){
	    $desc .= $row->[1];
	}
	
	if( !defined($desc) ) {
	    $desc = "no description available";
	}
	
	#Check for matches to required desc terms:
	if(@required_terms){
	    my $nomatch = 1;
	    foreach my $rt (@required_terms){
		if ($desc =~ m/$rt/i){
		    $nomatch = 0;
		}
	    }
	    
	    if ($nomatch){
		$logger->info("REJECTED: $longseqname description did not match your required terms [$desc]!\n");
		$descrequirerejected++;
		next BIGLOOP;
	    }
	}
	
	#Check for matches to forbidden desc terms:
	if ($forbidden){
	    foreach my $ft (@forbidden_terms){
		if ($desc =~ m/$ft/i){
		    $logger->info("REJECTED: $longseqname description matched a forbidden term, $ft desc=[$desc]!\n");
		    $descforbidrejected++;
		    next BIGLOOP;
		}
	    }
	}
	
	#Check ALIGN seq is not too similar to the other seqs we've selected:
	foreach my $longseqname3 (keys %ALIGN2SEEDcandidates){
	    my $p2 = pid($ALIGNhash{$longseqname},$ALIGN2SEEDcandidates{$longseqname3});
	    $pidcounts++;
	    if ($p2>=$maxpid){
		$ok = 0;
		$pidrejected++;
		if ($info){
		     printf "REJECTED: $longseqname too similar to $longseqname3 in ALIGN2SEEDcandidates (id=%0.3f)!\n", $p2; #Logger is really pants, eh!
		}
		next BIGLOOP;
	    }
	}
	
	#Calculate min and max PIDs between the ALIGN seq and SEED seqs:
	my $longseqname_max = "";
	foreach my $longseqname2 (keys %ALIGNandSEEDhash){
	    my $p = pid($ALIGNhash{$longseqname},$ALIGNhash{$longseqname2});
	    $pidcounts++;
	    if ($minpid{$longseqname}>$p){
		$minpid{$longseqname}=$p;
	    }

	    if ($maxpid{$longseqname}<$p){
		$maxpid{$longseqname}=$p;
		$longseqname_max = $longseqname2;
	    }
	    
	}
	
	if ($pidcounts==0 || $maxpid{$longseqname}==0.0){
	    $maxpid{$longseqname} = ($minpid+$maxpid)/2;
	}
	
	#If the max PID between ALIGN seq and SEED seqs is outside our limits:
	if ( $maxpid{$longseqname} < $minpid || $maxpid < $maxpid{$longseqname} ){
	    $ok = 0;
	    if ($info){
		printf "REJECTED: $longseqname max pid outside allowed range, ID=$longseqname_max (id=%0.3f)!\n", $maxpid{$longseqname}; #Yep, totally underwhelmed by this logger thing.
	    }
	    $pidrejected++;
	    next BIGLOOP;
	}
	
	$align2seedcount++;
	my $ungapped = $ALIGNhash{$longseqname};
	$ungapped =~ s/[,\.\-:_]//g;
	
	printf OUT ">$longseqname\t%0.3f\t%0.3f\t$desc\n$ungapped\n", $maxpid{$longseqname}, $persequence; 
	    if ($info){
		printf "ACCEPTED: maxpid:%0.3f\tFcbp:%0.3f\t$longseqname\t$desc\n", $maxpid{$longseqname}, $persequence; #It'd be damned embarrassing if logger did turn out to support formatted output afterall...
	    }
	$ALIGN2SEEDcandidates{$longseqname}=$ALIGNhash{$longseqname};
	
    }
    else {#Print DE lines for the SEED sequences:
	
	#Grab seq description:
	my $desc; 
	$sth->execute($ALIGNnames{$longseqname});
	my $res = $sth->fetchall_arrayref;
	foreach my $row (@$res){
	    $desc .= $row->[1];
	}

	if( !defined($desc) ) {
	    $desc = "no description available";
	}
	
	printf "SEED\t\t$longseqname\t%s\n", substr($desc,0,70);
    }
}
close(OUT);
$dbh->disconnect;

my $tot = $truncrejected+$structrejected+$pidrejected+$descforbidrejected+$descrequirerejected;
$logger->info("rejected $tot sequences, TRUNCATED:$truncrejected, STRUCTURE:$structrejected, DESC.forbid:$descforbidrejected, DESC.require:$descrequirerejected, PID:$pidrejected");


if ($align2seedcount>0){
    $logger->info( "Building new SEED (adding $align2seedcount squences):");
    
    system("/software/rfam/extras/infernal-0.81/src/cmbuild -F CM.81 SEED") and $logger->logdie("FATAL: Error in: [/software/rfam/extras/infernal-0.81/src/cmbuild -F CM.81 SEED].\n");
    system("/software/rfam/extras/infernal-0.81/src/cmalign --withpknots --withali SEED -o SEED.new CM.81 ALIGN2SEED") and $logger->logdie( "FATAL: Error in [/software/rfam/extras/infernal-0.81/src/cmalign --withpknots --withali SEED -o SEED.new CM.81 ALIGN2SEED].\n");
    
    $logger->info("Added $align2seedcount sequences\n");
    $logger->info("\trejected $tot sequences, TRUNCATED:$truncrejected, STRUCTURE:$structrejected DESC.forbid:$descforbidrejected, DESC.require:$descrequirerejected, PID:$pidrejected\n");
}
else {
    $logger->info( "No ALIGN2SEED candidates.\n");
    $logger->info( "rejected $tot sequences, TRUNCATED:$truncrejected, STRUCTURE:$structrejected, DESC.forbid:$descforbidrejected, DESC.require:$descrequirerejected, PID:$pidrejected\n");
}

#Finished!
exit();

######################################################################
# Should add these functions to Rfam modules: 
sub overlap {
    my($x1, $y1, $x2, $y2) = @_;
    
    if ( ($x1<=$x2 && $x2<=$y1) || ($x1<=$y2 && $y2<=$y1) || ($x2<=$x1 && $x1<=$y2) || ($x2<=$y1 && $y1<=$y2)  ){
        return 1;
    }
    else {
        return 0;
    }
}

sub pid {
    my $a = shift;
    my $b = shift;
    
    my @a = split(//, $a);
    my @b = split(//, $b);
    my ($sim, $lena, $lenb) = (0, 0, 0);
    
    if (scalar(@a) != scalar(@b)){
	return 0;
    }
    else {
	
 	for (my $i=0; $i<scalar(@b); $i++){
	    if ( (is_nucleotide($a[$i]) || is_nucleotide($b[$i])) && $a[$i] eq $b[$i] ){
		$sim++;
	    }
	    
	    if ( is_nucleotide($a[$i]) ){
		$lena++;
	    }

	    if ( is_nucleotide($b[$i]) ){
		$lenb++;
	    }
	}
    }
    
    my $maxlen = max($lena, $lenb);
    if ($maxlen>0){
	return $sim/$maxlen;
    }
    else {
	return 0;
    }
}


######################################################################
#returns true if input character is a nucleotide (IUPAC codes):
sub is_nucleotide {
    my $a = shift;
    return ($a =~ m/[ACGUTRYWSMKBDHVN]/i) ? 1 : 0; #Tried using "$_", didn't work...
}

######################################################################
#returns true if the two input characters can form a canonical/watson-crick basepair
sub is_complementary {
    my $a = shift;
    my $b = shift;
    my $ab = uc($a . $b);
    
    return (defined($canonical_basepair{$ab} )) ? 1 : 0;
}


######################################################################
#make_pair_table: takes a structure string and returns an array/pair_table.
#                 pair_table[0] contains the length of the string.
#                 pair_table[1..pair_table[0]] contains 0's if no basepair exists 
#                 for this position, otherwise it contains the index for the 
#                 corresponding pair.
#                 Eg. make_pair_table(".((...))") returns:
#                 (8,0,8,7,0,0,0,3,2)
######################################################################
sub make_pair_table {

    my $str = shift;
        
    my (%bpsymbs_posns, @pair_table, $prime5, $prime3, %bpsymbs3p5p, %bpsymbs3p5p_counts);
    my ($count, $unbalanced) = (0,0);

    #Match up the 5' and 3' basepair simbols:
    my %bpsymbs5p3p = (
	'(' => ')',
	'<' => '>',
	'[' => ']',
	'{' => '}',
	A => 'a',
	B => 'b',
	C => 'c',
	D => 'd',
	E => 'e',
	F => 'f',
	G => 'g',
	H => 'h',
	I => 'i'
	);

    my %bpsymbs5p3p_counts = (
	'(' => 0,
	'<' => 0,
	'[' => 0,
	'{' => 0,
	A => 0,
	B => 0,
	C => 0,
	D => 0,
	E => 0,
	F => 0,
	G => 0,
	H => 0,
	I => 0
	);
    
    #We also need the reverse of the above hashes (ie. Match the 3' symbols with the 5'):
    foreach my $symb5p (keys %bpsymbs5p3p){
	my $symb3p = $bpsymbs5p3p{$symb5p};
	$bpsymbs3p5p{$symb3p} = $symb5p;
	$bpsymbs3p5p_counts{$symb3p} = 0;
    }
    
    my %unpairedsymbs = (
	'.' => 1,
	',' => 2,
	'-' => 3,
	':' => 4,
	'_' => 5
	);
    
    my @ss = split(//,$str);
    $pair_table[0]  = length($str);
    
    my $j=0;
    foreach my $char (@ss){
	$j++;
	$pair_table[$j] = 0;
	
	if ( defined( $unpairedsymbs{$char} ) ) {
	    next; #Boring unpaired region.
	}
	elsif ( defined( $bpsymbs5p3p{$char}) ){#Record position of open bps:
	    push( @{ $bpsymbs_posns{$char} }, $j);
	    ++$count;
	    $bpsymbs5p3p_counts{$char}++;
	}
	elsif ( defined( $bpsymbs3p5p{$char}) ){#close bp, save positions of matches in pair_table:
	    my $mchar = $bpsymbs3p5p{$char};
	    $prime5 = pop( @{ $bpsymbs_posns{$mchar} } );
	    $prime3 = $j;
	    $pair_table[$prime3] = $prime5;
	    $pair_table[$prime5] = $prime3;
	    --$count;
	    $bpsymbs3p5p_counts{$char}++;
	}
       	else {
	    printf STDERR "Strange character \"$char\" in secondary structure:\n$str\n";
	}
    }
    
    #Check basepair symbols are all matched:
    foreach my $symb5p (keys %bpsymbs5p3p_counts){
	my $symb3p = $bpsymbs5p3p{$symb5p};
	my $diff = $bpsymbs5p3p_counts{$symb5p} - $bpsymbs3p5p_counts{$symb3p};
	if ($diff!=0){
	    printf STDERR "BAD EVIL AND NASTY: Unbalanced brackets in secondary structure:\n$bpsymbs5p3p_counts{$symb5p}x\'$symb5p\' and $bpsymbs3p5p_counts{$symb3p}x\'$symb3p\'\n";
	    $unbalanced = 1;
	}
    }
    
    
    if ($count != 0 || $unbalanced){
	printf STDERR "Unbalanced basepair symbols in secondary structure:\n$str\n";
	return ();
    }    
    else {
	return @pair_table;
    }
    
}

######################################################################
sub max {
  return $_[0] if @_ == 1;
  $_[0] > $_[1] ? $_[0] : $_[1]
}

sub min {
  return $_[0] if @_ == 1;
  $_[0] < $_[1] ? $_[0] : $_[1]
}

######################################################################
sub help {
    
    my $forbidden_terms = join(',',@forbidden_terms); 
    print STDERR <<EOF;

ALIGN2SEED.pl - reads in Stockholm format files SEED and ALIGN from the current dir. 
                Identifies sequences (S) in the ALIGN file that may be useful for including
                in the SEED. Sequences to be shifted into ALIGN must fulfil some criteria.
                For inclusion Max_ID(S) compared to the SEED seqs in ALIGN must lie between 
                $minpid and $maxpid. Also, to prevent truncated sequences from inclusion into SEED
                we make the restriction that at least one standard nucleotide character must
                lie within the first and last $nucends nucleotides in the ALIGN alignment. The minumum
                basepair consistency is $bpconsistency.
                
Usage:   ALIGN2SEED.pl <options>

Options:       
  -h or -help       (show this help)
  -minpid    <num>  (default is $minpid)
  -maxpid    <num>  (default is $maxpid)
  -nucends   <num>  (default is $nucends)
  -bpcons    <num>  (default is $bpconsistency)
  -required  <str>  (a required term for DE lines, eg. \"-required tRNA\", only accepts sequences matching this term. 
		     For multiple terms use another instance eg. \"-required transfer\", this matches tRNA \42OR\42 
		     transfer. Default is the empty string)
  -forbidden        (rejects seqs with  DE lines matching the forbidden terms: $forbidden_terms)
  -noforbidden      (dont use the forbidden terms, default is to use them [forbidden=$forbidden])
  -info             (print lots of info)
  -noinfo           (dont print lots of info, default is to print [info=$info])

To Add:  -Only accept seqs from Higher score threshold? Eg. top 50%
        
EOF
}