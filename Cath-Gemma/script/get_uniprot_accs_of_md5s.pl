#!/usr/bin/env perl

=usage

get_uniprot_accs_of_md5s.pl

Consider using:

setenv DBIC_TRACE console

...or...

export DBIC_TRACE=console

...if you want more info on the DB queries

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use Data::Dumper;
use English             qw/ -no_match_vars /;
use feature             qw/ say            /;
use List::Util          qw/ shuffle        /;
use FindBin;

# Find non-core external lib directory using FindBin
use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use List::MoreUtils     qw/ natatime       /;
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;

# Cath::Gemma
use Cath::Schema::Biomap;

# The number of IDs to which everything should be limited
# (or undef for (no no, no no no no, no no no no, no no there's) no limit)
my $NUM_IDS;
# my $NUM_IDS    = 5000;

# The number of IDs per DB query batch
# (Oracle appears to have a limit of 1000)
my $BATCH_SIZE = 999;

my $orig_seqs_data = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/shared/used/domseq_data_gene3d_12_31072013/persf/3.30.70.1470.faa' );

if ( ! -s $orig_seqs_data ) {
	confess 'Argh $orig_seqs_data';
}

INFO 'Reading IDs from ' . $orig_seqs_data;
my $orig_seqs_fh = $orig_seqs_data->openr();
my %seq_of_orig_id;
my %md5_of_orig_id;
while ( my $orig_seqs_line = <$orig_seqs_fh> ) {
	while ( chomp( $orig_seqs_line ) ) {}
	if ( $orig_seqs_line =~ /^>(\S+)$/ ) {
		my $id = $1;
		$orig_seqs_line = <$orig_seqs_fh>;
		my $seq = $orig_seqs_line;
		while ( chomp( $seq ) ) {}
		my @a = ( $id, $seq );
		my $md5 = $id;
		$md5 =~ s/\/.*$//g;
		$md5_of_orig_id{ $id } = $md5;
		$seq_of_orig_id{ $id } = $seq;
	}
	else {
		confess $orig_seqs_line;
	}
}
$orig_seqs_fh->close();

my @ids = shuffle( values( %md5_of_orig_id ) );

INFO 'Found ' . scalar( @ids ) . ' distinct MD5 ids from ' . scalar( keys ( %md5_of_orig_id ) ) . ' IDs';



if ( defined( $NUM_IDS ) ) {
	INFO 'Processing a limit of ' . $NUM_IDS . ' ids';
	@ids = @ids[ 0 .. $NUM_IDS ];
}



INFO 'Connecting to DB';
my $db = Cath::Schema::Biomap->connect_by_version( 'v4_0' )
	or confess;

my %results;

my $ids_batch_itr = natatime $BATCH_SIZE, @ids;
while (my @batch_ids = $ids_batch_itr->() ) {
	INFO 'Querying DB with ' . scalar( @batch_ids ) . ' ids';

	my @batch_results = map {
		my %columns = $ARG->get_columns();
		[ $columns{ sequence_md5 }, $columns{ uniprot_acc } ];
	} $db->resultset( 'UniprotAccession' )->search(
		{
			sequence_md5 => {
				IN => \@batch_ids,
			}
		},
		{
			select => [ qw/ sequence_md5 uniprot_acc / ],
			as     => [ qw/ sequence_md5 uniprot_acc / ],
		}
	)->all();

	foreach my $batch_result ( @batch_results ) {
		push @{ $results{ $batch_result->[ 0 ] } }, $batch_result->[ 1 ];
	}
}

foreach my $orig_id ( sort( keys( %md5_of_orig_id ) ) ) {
	my $md5          = $md5_of_orig_id{ $orig_id };
	my $uniprot_accs = $results{ $md5_of_orig_id{ $orig_id } };
	my $seq          = $seq_of_orig_id{ $orig_id };
	if ( ! defined( $uniprot_accs ) ) {
		warn 'Did not find any UniProt accessions for ' . $md5;
		next;
	}
	say $uniprot_accs->[ 0 ] . ' ' . $orig_id . ' ' . $seq_of_orig_id{ $orig_id };
}

=head1 NAME

make_starting_clusters.pl - Make sequences files for clusters with GO annotations

=head1 SYNOPSIS

perl -I extlib/lib/perl5 script/make_starting_clusters.pl [options]

=head1 OPTIONS

    -h [ --help ]                       Output usage message

    -c [ --cluster-infile ] <file>      Read cluster membership from file <file>
    -i [ --ids-go-terms-infile ] <file> Read IDs and GO terms from file <file>
    -s [ --sequences-infile ] <file>    Read sequences from file <file>

    -o [ --membership-outdir ] <dir>    Output help message

    -g [ --excluded-go-terms ] <list>   Only consider GO terms beginning IEA: if they're in comma-separated list <list>
                                        Default: IEA:UniProtKB-KW,IEA:UniProtKB-EC
=head1 DESCRIPTION

Make the starting clusters for GeMMA to process as part of the FunFam protocol.

This identifies the clusters that have any (non-excluded) GO annotations
and writes out the sequence files for them.

All GO terms beginning with N are excluded.

To understand how to use this script, see:

See https://github.com/UCL/cath-gemma/wiki/Running-the-Full-FunFam-Protocol

=cut
