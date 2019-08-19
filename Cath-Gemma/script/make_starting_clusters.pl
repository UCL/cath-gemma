#!/usr/bin/env perl

# Strict/warnings
use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use feature             qw/ say            /;
use FindBin;
use Getopt::Long;
use List::Util          qw/ max min none   /;
use Pod::Usage;

# This is to parse FASTA file - we might need to remove if the dependency is an issue...
use Bio::SeqIO;

# Find non-core external lib directory using FindBin
use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;

my $help = undef;

my $CLUSTER_INFILE;     #   = path( 'nr90.out.clstr'    );
my $SEQUENCES_INFILE;   #   = path( 'sequences.fa'      );
my $IDS_GO_TERMS_INFILE;#   = path( 'ids_go_terms.out'  );

my $INCLUDED_GO_IEA_TERMS = '';

my $MEMBERSHIP_OUTDIR     = path( 'starting_clusters' );

Getopt::Long::Configure( 'bundling' );
GetOptions(
	'h|help'                    => \$help,

	'c|cluster-infile=s'        => \$CLUSTER_INFILE,
	's|sequences-infile=s'      => \$SEQUENCES_INFILE,

	'i|ids-go-terms-infile=s'   => \$IDS_GO_TERMS_INFILE,

	'o|membership-outdir=s'     => \$MEMBERSHIP_OUTDIR,

	'g|included-go-iea-terms=s' => \$INCLUDED_GO_IEA_TERMS,
) or pod2usage( 2 );

if ( $help ) {
	pod2usage( 1 );
}

if (!$CLUSTER_INFILE || !$SEQUENCES_INFILE) {
	pod2usage(3);
}

$CLUSTER_INFILE      = path( $CLUSTER_INFILE      );
$MEMBERSHIP_OUTDIR   = path( $MEMBERSHIP_OUTDIR   );
$SEQUENCES_INFILE    = path( $SEQUENCES_INFILE    );

my %INCLUDED_GO_IEA_TERMS = map { ( $ARG, 1 ); } split( /,/, $INCLUDED_GO_IEA_TERMS );

my $APPLY_GO_FILTER = $IDS_GO_TERMS_INFILE ? 1 : 0;

# Read the GO terms file
my %id_with_go;
if ( $APPLY_GO_FILTER ) {
	$IDS_GO_TERMS_INFILE = path( $IDS_GO_TERMS_INFILE );

	INFO "Reading GO terms file $IDS_GO_TERMS_INFILE";
	my $ids_go_terms_contents = $IDS_GO_TERMS_INFILE->slurp();
	my @ids_go_terms_contents = split( /\n+/, $ids_go_terms_contents );
	while ( chomp( @ids_go_terms_contents ) ) {}

	# Record the IDs that have associated GO terms
	foreach my $ids_go_terms_line ( @ids_go_terms_contents ) {
		my @ids_go_terms_lineparts = split( /\s+/, $ids_go_terms_line );

		my ( $id, $go_code, $go_term ) = @ids_go_terms_lineparts;
		if ( $go_term !~ /^N/ && ( $go_term !~ /^IEA:/ || ( $INCLUDED_GO_IEA_TERMS{ $go_term } ) ) ) {
			$id_with_go{ $id } = 1;
		}
	}
}
else {
	INFO "Not applying GO filtering";
}

# Read in lines of S90 cluster membership file
INFO "Reading cd-hit S90 clusters file $CLUSTER_INFILE";
my $cluster_contents = $CLUSTER_INFILE->slurp();
my @cluster_lines    = split( /\n+/, $cluster_contents );

# Build data structure of S90 clusters
my @new_clusters;
foreach my $cluster_line ( @cluster_lines ) {
	if ( $cluster_line =~ /^>Cluster/ ) {
		push @new_clusters, [];
		next;
	}

	my @cluster_line_parts = split( /\s+/, $cluster_line );
	my ( $clust_memb_num, $cd_hit_id, $id ) = @cluster_line_parts;

	$id =~ s/^>//g;
	$id =~ s/\.+$//g;

	push @{ $new_clusters[ -1 ] }, $id;
}
undef @cluster_lines;
undef $cluster_contents;

# Remove clusters without GO annotations
if ( scalar( @new_clusters ) == 0 ) {
	WARN 'There are no clusters at this point in the processing!!';
}

if ($APPLY_GO_FILTER) {
	INFO 'Removing clusters without suitable GO annotations (...starting with ' . scalar( @new_clusters ) . ' clusters)';
	my @del_indices = grep {
		my $clust_idx = $ARG;
		none { exists( $id_with_go{ $ARG } ) } @{ $new_clusters[ $clust_idx ] };
	} ( 0 .. $#new_clusters );
	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @new_clusters, $reverse_index, 1 );
	}
	INFO 'After removing clusters without suitable GO annotations, there are now ' . scalar( @new_clusters ) . ' clusters';
}

if ( scalar( @new_clusters ) == 0 ) {
	WARN '!!!! There are no clusters at this point in the processing !!!!';
}

# Read the sequences
INFO "Reading sequences from file $SEQUENCES_INFILE";

my $seqio = Bio::SeqIO->new( -file => "$SEQUENCES_INFILE", -format => "Fasta" );
my %sequence_of_id;
while ( my $seq = $seqio->next_seq ) {
	my $id = $seq->id;
	$sequence_of_id{ $id } = $seq->seq;
}

# Write sequences to files
INFO "Writing sequences to cluster files in directory $MEMBERSHIP_OUTDIR";
if ( ! -d $MEMBERSHIP_OUTDIR ) {
	$MEMBERSHIP_OUTDIR->mkpath()
		or confess 'Unable to make output directory "' . $MEMBERSHIP_OUTDIR . '" : ' . $OS_ERROR;
}
my $max_seq_variance_pc   = undef;
my $max_seq_variance_file = undef;
foreach my $new_cluster_ctr ( 0 .. $#new_clusters ) {
	my $new_cluster  = $new_clusters[ $new_cluster_ctr ];
	my $out_seq_file = $MEMBERSHIP_OUTDIR->child( 'working_' . ( $new_cluster_ctr + 1 ) . '.faa' );
	my $max_seq_length = max map { length( $sequence_of_id{ $ARG } ); } @$new_cluster;
	my $min_seq_length = min map { length( $sequence_of_id{ $ARG } ); } @$new_cluster;
	$out_seq_file->spew( join(
		'',
		map {
			'>' . $ARG . "\n" . $sequence_of_id{ $ARG } . "\n"
		} @$new_cluster
	) );
	my $seq_variance_pc = ( 100.0 * $max_seq_length / $min_seq_length );
	if ( !defined( $max_seq_variance_pc ) || $seq_variance_pc > $max_seq_variance_pc ) {
		$max_seq_variance_pc   = $seq_variance_pc;
		$max_seq_variance_file = $out_seq_file;
		INFO 'Largest variation in sequence length within a cluster so far : '
			. $max_seq_variance_pc
			. ' ('
			. $max_seq_variance_file
			. ')';
	}
}

=head1 NAME

make_starting_clusters.pl - Make sequences files for clusters with GO annotations

=head1 SYNOPSIS

make_starting_clusters.pl [options] -c <file> -s <file> [-i <file>]

=head1 OPTIONS

    -h [ --help ]                         Output usage message

    -c [ --cluster-infile ] <file>        Read cluster membership from file <file>
    -s [ --sequences-infile ] <file>      Read sequences from file <file>

    -i [ --ids-go-terms-infile ] <file>   Read IDs and GO terms from file <file>

    -o [ --membership-outdir ] <dir>      Output directory 
                                          (default: './starting-clusters')

    -g [ --included-go-iea-terms ] <list> Only consider GO terms beginning IEA if 
                                          they are in comma-separated list <list>
                                          eg: 'IEA:UniProtKB-KW,IEA:UniProtKB-EC'
                                          (default: '')

=head2 DESCRIPTION

Make the starting clusters for GeMMA to process as part of the FunFam protocol.

This identifies the clusters that have any (non-excluded) GO annotations
and writes out the sequence files for them.

All GO terms beginning with N are excluded.

To understand how to use this script, see:

https://github.com/UCL/cath-gemma/wiki/Running-the-Full-FunFam-Protocol

=cut
