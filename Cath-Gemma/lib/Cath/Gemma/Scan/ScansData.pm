package Cath::Gemma::Scan::ScansData;

=head1 NAME

Cath::Gemma::Scan::ScansData - Store the matrix of links between clusters of starting clusters

=head2 Overview

This handles:
 * the matrix of links via LinkMatrix
 * the starting clusters within each cluster via StartingClustersOfId

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                                                                 /;
use English             qw/ -no_match_vars                                                          /;
use List::Util          qw/ max maxstr min minstr sum                                               /;
use POSIX               qw/ log10                                                                   /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use List::MoreUtils     qw/ first_value                                                             /;
use List::UtilsBy       qw/ min_by                                                                  /;
use Log::Log4perl::Tiny qw/ :easy                                                                   /;
use Type::Params        qw/ compile                                                                 /;
use Types::Standard     qw/ ArrayRef ClassName CodeRef HashRef Num Tuple Object Optional slurpy Str /;

# Cath::Gemma
use Cath::Gemma::Scan::Impl::LinkMatrix;
use Cath::Gemma::StartingClustersOfId;
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaScanImplLinks
	CathGemmaScanScanData
	CathGemmaScanScansData
	CathGemmaStartingClustersOfId
/;
use Cath::Gemma::Util;

=head2 _starting_clusts_of_clust_id

Store the starting clusters of each cluster

=cut

has _starting_clusts_of_clust_id => (
	is          => 'rwp',
	isa         => CathGemmaStartingClustersOfId,
	handles     => [
		'contains_id',                 # Whether this contains a cluster with the specified ID
		'count',                       # The number of clusters
		'get_starting_clusters_of_id', # Get the list of starting clusters within the cluster with the specified ID
		'no_op_merge_pair',            # Return the results of performing a dry-run merge (see StartingClustersOfId::no_op_merge_pair() for more info)
		'no_op_merge_pairs',           # Return the results of performing a dry-run of a list of merges (see StartingClustersOfId::no_op_merge_pair() for more info)
		'sorted_ids',                  # Get a sorted list of the cluster IDs
	],
	default     => sub { Cath::Gemma::StartingClustersOfId->new(); },
);

=head2 _links_matrix

Store the links between the clusters

=cut

has _links_matrix => (
	is          => 'rwp',
	isa         => CathGemmaScanImplLinks,
	default     => sub { Cath::Gemma::Scan::Impl::LinkMatrix->new(); },
	handles     => [
		'get_id_and_score_of_lowest_score_of_id', # Get the IDs and score of the result with the lowest score *to the cluster with the specified index*
		'get_score_between',                      # Get the score between the two clusters with the specified IDs
		'ids',                                    # Get the list of cluster IDs
		'ids_and_score_of_lowest_score_result',   # TODOCUMENT
		'ids_and_score_of_lowest_score_window',   # TODOCUMENT
	],
);

=head2 add_separate_starting_clusters

Add the specified clusters as separate (ie non-linked) starting clusters

=cut

sub add_separate_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	$self->_links_matrix()->add_separate_clusters( $ids );
	$self->_starting_clusts_of_clust_id()->add_separate_starting_clusters( $ids );
	return $self;
}

=head2 add_starting_clusters_group_by_id

TODOCUMENT

=cut

sub add_starting_clusters_group_by_id {
	state $check = compile( Object, ArrayRef[Str], Optional[Str] );
	my ( $self, $starting_clusters, $id ) = $check->( @ARG );

	$self->_links_matrix()->add_starting_clusters_group_by_id( $starting_clusters, $id );
	return $self->_starting_clusts_of_clust_id()->add_starting_clusters_group_by_id( $starting_clusters, $id );
}

=head2 add_scan_entry

Add a single scan result (ie a single link)

Pre-condition: both cluster IDs must already be known to this ScansData

=cut

sub add_scan_entry {
	state $check = compile( Object, Str, Str, Num );
	my ( $self, $cluster_id1, $cluster_id2, $score ) = $check->( @ARG );

	foreach my $cluster_id ( $cluster_id1, $cluster_id2 ) {
		if ( ! defined( $self->contains_id( $cluster_id ) ) ) {
			use Data::Dumper;
			confess "Cannot add scan_entry for unrecognised ID \"$cluster_id\" " . Dumper( $self->_starting_clusts_of_clust_id() );
		}
	}

	$self->_links_matrix()->add_scan_entry( $cluster_id1, $cluster_id2, $score );
}

=head2 add_scan_data

TODOCUMENT

=cut

sub add_scan_data {
	state $check = compile( Object, CathGemmaScanScanData );
	my ( $self, $scan_data ) = $check->( @ARG );

	foreach my $scan_entry ( @{ $scan_data->scan_data() } ) {
		$self->add_scan_entry( @$scan_entry );
	}
}

=head2 ids_and_score_of_lowest_score_or_arbitrary

TODOCUMENT

=cut

sub ids_and_score_of_lowest_score_or_arbitrary {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $result = $self->ids_and_score_of_lowest_score_result();
	if ( defined( $result ) ) {
		return $result;
	}

	DEBUG "Returning from ids_and_score_of_lowest_score_or_arbitrary() with arbitrary result due to there being no usable scores between clusters";
	my $sorted_ids = $self->sorted_ids();
	return [ $sorted_ids->[ 0 ], $sorted_ids->[ 1 ], "inf" ];
}

=head2 merge_pair

Remove the specified nodes and return the starting clusters associated with them,
ordered according to the specified CathGemmaNodeOrdering

=cut

sub merge_pair {
	state $check = compile( Object, Str, Str, CodeRef, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, $score_update_function, @clusts_ordering ) = $check->( @ARG );

	my $merged_starting_clusters = combine_starting_cluster_names(
		$self->_starting_clusts_of_clust_id()->remove_id( $id1 ),
		$self->_starting_clusts_of_clust_id()->remove_id( $id2 ),
		@clusts_ordering
	);
	my $other_ids = $self->sorted_ids();
	my $merged_node_id = $self->_starting_clusts_of_clust_id()->add_starting_clusters_group_by_id(
		$merged_starting_clusters
	);
	$self->_links_matrix()->merge_pair(
		$merged_node_id,
		$id1,
		$id2,
		$score_update_function
	);

	return [
		$merged_node_id,
		$merged_starting_clusters,
		$other_ids,
	];
}

=head2 merge_pair_without_new_scores

TODOCUMENT

=cut

sub merge_pair_without_new_scores {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, @clusts_ordering ) = $check->( @ARG );

	return $self->merge_pair(
		$id1,
		$id2,
		sub { undef; },
		@clusts_ordering
	);
}

=head2 merge_pairs

TODOCUMENT

=cut

sub merge_pairs {
	state $check = compile( Object, ArrayRef[Tuple[Str, Str]], CodeRef, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id_pairs, $score_update_function, @clusts_ordering ) = $check->( @ARG );

	return [
		map {
			my ( $id1, $id2 ) = @$ARG;
			$self->merge_pair( $id1, $id2, $score_update_function, @clusts_ordering );
		} @$id_pairs
	];
}


=head2 merge_pairs_without_new_scores

TODOCUMENT

=cut

sub merge_pairs_without_new_scores {
	state $check = compile( Object, ArrayRef[Tuple[Str, Str]], Optional[CathGemmaNodeOrdering] );
	my ( $self, $id_pairs, @clusts_ordering ) = $check->( @ARG );

	return [
		map {
			my ( $id1, $id2 ) = @$ARG;
			$self->merge_pair( $id1, $id2, sub { undef; }, @clusts_ordering );
		} @$id_pairs
	];
}

=head2 merge_pair_using_lowest_score

TODOCUMENT

TODO: Consider returning the full merge data

=cut

sub merge_pair_using_lowest_score {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, @clusts_ordering ) = $check->( @ARG );

	return $self->merge_pair(
		$id1,
		$id2,
		sub {
			my ( $score1, $score2 ) = @ARG;
			$score1 = ( defined( $score1 ) && lc( $score1 ) ne 'inf' ) ? $score1 : undef;
			$score2 = ( defined( $score2 ) && lc( $score2 ) ne 'inf' ) ? $score2 : undef;

			# TODO: The below code doesn't really make much sense. Replace with:
			# return ( defined( $score1 ) && defined( $score2 ) )
			# 	? min( $score1, $score2 )
			# 	: ( $score1 // $score2 // 'inf' );
			return
				defined( $score1 )
				? (
					defined( $score2 )
					? min( $score2, $score1 )
					: $score1
				)
				: 'inf';
		},
		@clusts_ordering
	)->[ 0 ];
}

=head2 merge_pair_using_highest_score

TODOCUMENT

TODO: Consider returning the full merge data

=cut

sub merge_pair_using_highest_score {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, @clusts_ordering ) = $check->( @ARG );

	return $self->merge_pair(
		$id1,
		$id2,
		sub {
			my ( $score1, $score2 ) = @ARG;
			$score1 = ( defined( $score1 ) && lc( $score1 ) ne 'inf' ) ? $score1 : undef;
			$score2 = ( defined( $score2 ) && lc( $score2 ) ne 'inf' ) ? $score2 : undef;

			# TODO: The below code doesn't really make much sense. Replace with:
			# return ( defined( $score1 ) && defined( $score2 ) )
			# 	? max( $score1, $score2 )
			# 	: 'inf';
			return defined( $score1 )
				? (
					defined( $score2 )
					? max( $score2, $score1 )
					: $score1
				)
				: 'inf';
		},
		@clusts_ordering
	)->[ 0 ];
}

=head2 merge_add_with_unweighted_geometric_mean_score

TODOCUMENT

=cut

sub merge_add_with_unweighted_geometric_mean_score {
	state $check = compile( Object, Str, Str, CathGemmaScanScansData, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, $orig_scans, @clusts_ordering ) = $check->( @ARG );

	my $starting_clusters_1 = $self->get_starting_clusters_of_id( $id1 );
	my $starting_clusters_2 = $self->get_starting_clusters_of_id( $id2 );

	return $self->merge_pair(
		$id1,
		$id2,
		sub {
			my ( $score1, $score2, $other_id ) = @ARG;
			if ( ! defined( $score1 ) || lc( $score1 ) eq 'inf' ) {
				return 'inf';
			}
			my $other_starting_clusters = $self->get_starting_clusters_of_id( $other_id );
			my @log_10_scores = 0;
			foreach my $starting_cluster ( @$starting_clusters_1, @$starting_clusters_2 ) {
				foreach my $other_starting_cluster ( @$other_starting_clusters ) {
					my $score = $orig_scans->get_score_between( $starting_cluster, $other_starting_cluster );
					$score = ( defined( $score ) && lc( $score ) ne 'inf' ) ? $score : undef;
					# If undefined, make      large
					# If zero,      make very small
					# Otherwise,    use value
					push @log_10_scores, log10( ( $score // 1e10 ) || 1e-200 );
				}
			}

			my $new_score = ( scalar( @log_10_scores ) > 0 )
				? ( 10 ** ( sum( @log_10_scores ) / scalar( @log_10_scores ) ) )
				: 'inf';
			# if ( defined( $new_score ) ) {
			# 	warn "$merged_node_id <- ( $id1 +\t$id2 )\t$other_id\t$new_score\n";
			# }

			return ( scalar( @log_10_scores ) > 0 )
				? ( 10 ** ( sum( @log_10_scores ) / scalar( @log_10_scores ) ) )
				: 'inf';
		},
		@clusts_ordering
	)->[ 0 ];
}


=head2 new_from_score_of_id_of_id

TODOCUMENT

=cut

sub new_from_score_of_id_of_id {
	state $check = compile( ClassName, HashRef[HashRef[Num]] );
	my ( $class, $data ) = $check->( @ARG );

	my $new = $class->new();
	foreach my $id1 ( sort( keys( %$data ) ) ) {
		my $data_of_id1 = $data->{ $id1 };
		foreach my $id2 ( sort( keys( %$data_of_id1 ) ) ) {
			$new->add_scan_entry( $id1, $id2, $data_of_id1->{ $id2 } );
		}
	}
	return $new;
}

=head2 new_from_starting_clusters

TODOCUMENT

=cut

sub new_from_starting_clusters {
	state $check = compile( ClassName, ArrayRef[Str] );
	my ( $class, $ids ) = $check->( @ARG );

	my $new = $class->new();
	$new->add_separate_starting_clusters( $ids );
	return $new;
}

1;
