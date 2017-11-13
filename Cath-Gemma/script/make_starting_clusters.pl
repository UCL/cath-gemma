#!/usr/bin/env perl

=usage

perl ./make_clusters.pl

=cut

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

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;


my $help = undef;

my $CLUSTER_INFILE        = path( 'nr90.out.clstr'    );
my $IDS_GO_TERMS_INFILE   = path( 'ids_go_terms.out'  );
my $SEQUENCES_INFILE      = path( 'sequences.fa'      );

my $INCLUDED_GO_IEA_TERMS = '';

my $MEMBERSHIP_OUTDIR     = path( 'starting_clusters' );


Getopt::Long::Configure( 'bundling' );
GetOptions(
	'h|help'                    => \$help,

	'c|cluster-infile=s'        => \$CLUSTER_INFILE,
	'i|ids-go-terms-infile=s'   => \$IDS_GO_TERMS_INFILE,
	's|sequences-infile=s'      => \$SEQUENCES_INFILE,

	'o|membership-outdir=s'     => \$MEMBERSHIP_OUTDIR,

	'g|included-go-iea-terms=s' => \$INCLUDED_GO_IEA_TERMS,
) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

$CLUSTER_INFILE      = path( $CLUSTER_INFILE      );
$IDS_GO_TERMS_INFILE = path( $IDS_GO_TERMS_INFILE );
$MEMBERSHIP_OUTDIR   = path( $MEMBERSHIP_OUTDIR   );
$SEQUENCES_INFILE    = path( $SEQUENCES_INFILE    );

my %INCLUDED_GO_IEA_TERMS = map { ( $ARG, 1 ); } split( /,/, $INCLUDED_GO_IEA_TERMS );

# Read the GO terms file
INFO "Reading GO terms file $IDS_GO_TERMS_INFILE";
my $ids_go_terms_contents = $IDS_GO_TERMS_INFILE->slurp();
my @ids_go_terms_contents = split( /\n+/, $ids_go_terms_contents );
while ( chomp( @ids_go_terms_contents ) ) {}

# Record the IDs that have associated GO terms
my %id_with_go;
foreach my $ids_go_terms_line ( @ids_go_terms_contents ) {
	my @ids_go_terms_lineparts = split( /\s+/, $ids_go_terms_line );

	my ( $id, $go_code, $go_term ) = @ids_go_terms_lineparts;
	if ( $go_term !~ /^N/ && ( $go_term !~ /^IEA:/ || ( $INCLUDED_GO_IEA_TERMS{ $go_term } ) ) ) {
		$id_with_go{ $id } = 1;
	}
}

undef @ids_go_terms_contents;
undef $ids_go_terms_contents;

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
INFO "Removing clusters without suitable GO annotations";
my @del_indices = grep {
	my $clust_idx = $ARG;
	none { exists( $id_with_go{ $ARG } ) } @{ $new_clusters[ $clust_idx ] };
} ( 0 .. $#new_clusters );

foreach my $reverse_index ( reverse( @del_indices ) ) {
	splice( @new_clusters, $reverse_index, 1 );
}

# Read the sequences
INFO "Reading sequences from file $SEQUENCES_INFILE";
my $sequences_contents = $SEQUENCES_INFILE->slurp();
my @sequences_lines = split( /\n+/, $sequences_contents );
my $id;
my %sequence_of_id;
foreach my $sequences_line ( @sequences_lines ) {
	if ( $sequences_line =~ /^>/ ) {
		if ( $id ) {
			ERROR "Found another ID in sequences after parsing ID $id";
			confess '';
		}
		$id = substr( $sequences_line, 1 );
	}
	else {
		if ( ! $id ) {
			ERROR 'Did not have a preceding ID whilst handling line "'. $sequences_line . '"';
			confess '';
		}
		$sequence_of_id{ $id } = $sequences_line;
		$id = undef;

	}
}
undef $sequences_contents;
undef @sequences_lines;


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

perl -I extlib/lib/perl5 script/make_starting_clusters.pl [options]

=head1 OPTIONS

    -h [ --help ]                         Output usage message

    -c [ --cluster-infile ] <file>        Read cluster membership from file <file>
    -i [ --ids-go-terms-infile ] <file>   Read IDs and GO terms from file <file>
    -s [ --sequences-infile ] <file>      Read sequences from file <file>

    -o [ --membership-outdir ] <dir>      Output help message

    -g [ --included-go-iea-terms ] <list> Only consider GO terms beginning IEA: if they're in comma-separated list <list>
                                          Eg: IEA:UniProtKB-KW,IEA:UniProtKB-EC
                                          Default: ''
=head1 DESCRIPTION

Make the starting clusters for GeMMA to process as part of the FunFam protocol.

This identifies the clusters that have any (non-excluded) GO annotations
and writes out the sequence files for them.

All GO terms beginning with N are excluded.

To understand how to use this script, see:

See https://github.com/UCL/cath-gemma/wiki/Running-the-Full-FunFam-Protocol

=cut
