#!/usr/local/bin/perl -w

use strict;

my $family = shift;

if( &desc_is_OK( "$family" ) ) {
    print STDERR "$family: No errors found\n";
}
else {
    print STDERR "$family: Your family contains errors\n";
    exit(1);
}

sub desc_is_OK {
    my $family = shift @_;
    my $error = 0;
    my $ref;
    my %fields;

    open(DESC, "$family/DESC") or die "Can't open $family/DESC file\n";
    while( <DESC> ) {
        chop;
        if( length $_ > 80 ) {
            warn "$family: Line greater than 80 chars [$_]\n";
            $error = 1;
        }
        if( /\r/ ) {
            warn "$family: DESC contains DOS newline characters\n";
            $error = 1;
            last;
        }

        SWITCH : {
          # Compulsory fields: These must be present
            /^AC/ && do { 
                $fields{$&}++;
                if (! /^AC   RF(\d\d\d\d\d)$/ ) {
                    warn "$family: Bad accession line [$_]";
                    $error = 1;
                }
                last;
            };
            /^ID/ && do { 
                $fields{$&}++;
                last;
            };
            /^DE/ && do { 
                $fields{$&}++; 
                if( !/^DE   .{1,80}/ ) {
                    warn "$family: DE lines should have 1 to 80 characters\n";
                    $error = 1;
                } elsif (/^DE.*s$/){
                    warn "$family: DE lines should not be plural!, please check and remove if plural\n";
                } elsif (/^DE.*\.$/){
		    warn "$family: DE lines should not end with a fullstop\n";
                }
                last; };
            /^AU/ && do { $fields{$&}++; last; };
            /^TC/ && do {
                $fields{$&}++; 
                if ( !/TC   \S+\s*$/){
                    warn "$family: TC lines should look like:\nTC   23.00\n";
                    $error = 1;
                }
                last; 
            };
            /^NC/ && do {
                $fields{$&}++; 
                if ( !/NC   \S+\s*$/){
                    warn "$family: NC lines should look like:\nNC   11.00\n";
                    $error = 1;
                }
                last; 
            };
            /^SE/ && do { $fields{$&}++; last; };
            /^GA/ && do {
                $fields{$&}++; 
                if (! /^GA   \S+\s*$/){
                    warn "$family: GA lines should look like:\nGA   20.00;\nNot $_\n";
                    $error = 1;
                }
               last;
            };
	    /^TP/ && do {
		$fields{$&}++;
		unless( /^TP   Site\s*$/ or /^TP   Gene\s*$/ or /^TP   Intron\s*$/ ) {
                    warn "$family: TP lines should be one of Site, Intron, Gene\nNot $_\n";
                    $error = 1;
 		}
                last;
	    };
            /^BM/ && do {
		if( not /^BM   cmbuild / and not /^BM   cmsearch / ) {
                    warn "$family: BM lines should start with cmbuild or cmsearch\n";
		    $error = 1;
		}
                $fields{$&}++;
                last;
            };
            /^SQ/ && do {
                $error = 1;
                warn "$family: DESC files should not contain SQ lines, please check and remove\n";
                last;
            };
            # Non-Compulsory fields: These may be present
            /^\*\*/ && do { last; };  # These are ** lines which are confidential comments.
            /^CC/ && do {
                if (/^CC\s+$/){
                    $error = 1;
                    warn "$family: DESC files should not contain blank CC lines, please check and remove\n";
                    last;
               } elsif (/^CC.*-!-/){
                    $error = 1;
                    warn "$family: DESC files should not contain -!- in CC lines, please check and remove\n";
                }
                last; 
            };
            /^RT/ && do { last; };
            /^RL/ && do { 
                if( !/^RL   .*\d+;\d+:(\d+)(?:-(\d+))?\.$/ and ! /^RL   .*\d+;\d+:RESEARCH.*$/) {
                    warn "$family: Bad reference line [$_]\nFormat is:    Journal abbreviation year;volume:page-page.\n
";
                    $error = 1;
                } else {
                    my $start = $1;
                    my $end = $2;
                    if( $end and $start > $end ) {
                        warn "$family: Your reference line has a start ($start) bigger than end ($end)";
                        $error = 1;
                    }
                }
                last; 
            };
            /^RN/ && do {
                $fields{$&}++;
                if( !/^RN   \[\d+\]/ ) {
                    warn "$family: Bad Ref No line [$_]\n";
                    $error = 1;
                }
                last;
            };
            /^RA/ && do { last; };
            /^RM/ && do  {
                $fields{$&}++;
                $ref=1;
                if( !/^RM   \d{7,8}$/) {
                    warn "$family: Bad Medline reference [$_]\nShould be a seven or eight digit number\n";
                    $error = 1;
                }
                last;
            };
            /^DR/ && do  {
                $ref=1;
                DBREF : { 
                    /^DR   EXPERT;\s+/ && do {
                        if( !/^DR   EXPERT;\s+\S+@\S+;$/ ) {
                            warn "$family: Bad expert reference [$_]\n";
                            $error = 1;
                            last SWITCH;
                        }
                        last SWITCH;
                    };
                    /^DR   URL;\s+(\S+);$/ && do {
                        warn "$family: Please check the URL $1\n";
                        last SWITCH;
                    };
                    warn "$family: Bad reference line: unknown database [$_]\n";
                    $error = 1;
                    last SWITCH;
                };
            };
            warn "$family: Unrecognised DESC file line [$_]\n";
            $error = 1;
        }
    }

    # Check compulsory feilds
    # there shouldn't be a AC line before the family is created!

#    if ($fields{AC} eq "0"){
#        warn "$family: There is no accession line. SERIOUS ERROR.\n";
#        $error = 1;
#    }
    if (exists $fields{AC} and $fields{AC} > 1){
        warn "$family: There are $fields{AC} accession lines. SERIOUS ERROR.\n";
        $error = 1;
    }
    if ($fields{TC} != 1){
        warn "$family: There are [$fields{TC}] TC lines. SERIOUS ERROR.\n";
        $error = 1;
    }
    if ($fields{NC} != 1){
        warn "$family: There are [$fields{NC}] NC lines. SERIOUS ERROR.\n";
        $error = 1;
    }
    if ($fields{TP} != 1){
        warn "$family: There are [$fields{TP}] TP lines. SERIOUS ERROR.\n";
        $error = 1;
    }
    if ($fields{DE} > 1){
        warn "$family: There are [$fields{DE}] description lines. The description must be on a single line.\n";
        $error = 1;
    }
    if ($fields{AU} eq "0"){
        warn "$family: There are no author lines\n";
        $error = 1;
    }
    if ($fields{AU} ne "1"){
        warn "$family: There are [$fields{AU}] author lines, there should only be one author line\n";
        $error = 1;
    }
    if ($fields{SE} ne "1"){
        warn "$family: There are [$fields{SE}] SE lines\n";
        $error = 1;
    }
    if ($fields{GA} ne "1"){
        warn "$family: There are [$fields{GA}] GA lines\n";
       $error = 1;
    }
    $fields{RN} = 0 if !exists $fields{RN};
    $fields{RM} = 0 if !exists $fields{RM};
    if ($fields{RN} ne $fields{RM}){
        warn "$family: There is a discrepancy between the number of RN ($fields{RN})and RM ($fields{RM})lines\n";
        $error = 1;
    }
    close(DESC);

    if( !$ref ) {
        warn "$family: DESC has no references\n";
    }

    if( $error ) {
        return 0;               # failure
    }
    else {
        return 1;               # success
    }
}

