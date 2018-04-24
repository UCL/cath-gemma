package Cath::Gemma::Scan::Impl::LinkMatrix;

=head1 NAME

Cath::Gemma::Scan::Impl::LinkMatrix - [For use in ScansData] Store the matrix of links between clusters
                                      (with no care for the clusters' composition from other clusters)

=head2 Overview

This stores the matrix of links (eg evalues) between clusters as part of the imp.

This is a reasonably CPU/memory performance sensitive area of code (particularly LinkList)

LinkMatrix contains:
 * a mapping to/from the ID string used by the outside world and a numeric index used here and in LinkList
 * an array of LinkLists (corresponding to the links with the clusters with the corresponding indices)

=head2 Relationship to LinkList

This and Cath::Gemma::Scan::Impl::LinkList should be seen as a closely-bound pair of classes
that share a bunch of implementation details. It probably doesn't make sense to try to
use or understand either in the absence of the other.

In particular:
 * they share a way of handling indexing clusters such that a new cluster is given a
   new number (incrementing from 0), rather than overwriting old clusters.
 * they share a way of being lazy about deleting old clusters: LinkMatrix doesn't get LinkList to eagerly
   update regarding every cluster that gets deleted by a merge; instead, it passes a list of the
   clusters that are still active whenever it queries for the current best result

=head2 Relationship to ScansData

This class is used by ScansData, which contains:
 * a `Cath::Gemma::Scan::Impl::LinkMatrix` to store the links between clusters, and
 * a `Cath::Gemma::StartingClustersOfId` that handles the groups of starting clusters in each cluster

(In short: ScansData cares what starting clusters each cluster contains; LinkMatrix doesn't)

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                                                                    /;
use Data::Dumper;
use English             qw/ -no_match_vars                                                             /;
use Storable            qw/ dclone                                                                     /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::UtilsBy       qw/ min_by                                                                     /;
use Log::Log4perl::Tiny qw/ :easy                                                                      /;
use Type::Params        qw/ compile                                                                    /;
use Types::Standard     qw/ ArrayRef ClassName CodeRef HashRef Int Maybe Num Object Optional Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Scan::Impl::LinkList;
use Cath::Gemma::Types qw/
	CathGemmaScanImplLinkList
/;
use Cath::Gemma::Util;

=head2 _id_of_index

Map from the numeric index that this and LinkList use back to the ID string that the outside world uses

An undef indicates an index that was previously used for an ID that has since been deleted
(presumably due to a merge operation).

=cut

has _id_of_index => (
	is          => 'rwp',
	isa         => ArrayRef[Maybe[Str]],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_get_id_of_index  => 'get',
		_num_indices      => 'count',
		_push_id_of_index => 'push',
		_set_id_of_index  => 'set',
	},
);

=head2 _index_of_id

Map from the ID string that the outside world uses to the numeric index that this and LinkList use

=cut

has _index_of_id => (
	is          => 'rwp',
	isa         => HashRef[Num],
	default     => sub { {}; },
	handles_via => 'Hash',
	handles     => {
		_contains_index_of_id => 'exists',
		_delete_index_of_id   => 'delete',
		_get_index_of_id      => 'get',
		_set_index_of_id      => 'set',
		count                 => 'count',
		ids                   => 'keys',
	},
);

=head2 _links_data

The links data, implemented as an array of `LinkList`s.

The indices from the ID/index mapping are used here both for the positions of the `LinkList`s in this
array and for the indices used within the LinkList

=cut

has _links_data => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaScanImplLinkList],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_num_link_lists => 'count',
		_get_links_data => 'get',
		_set_links_data => 'set',
	},
);

=head2 _checked_index_of_id

Check that the specified ID has a valid index and return it (else confess)

=cut

sub _checked_index_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	if ( ! $self->_contains_index_of_id( $id ) ) {
		confess 'Unable to find an index associated with the ID "' . $id . '"';
	}
	return $self->_get_index_of_id( $id );
}

=head2 _ensure_index_of_id

Ensure there is an index associated with the specified ID
(ie look for one and if one doesn't already exist then add the new index and
 return its newly assigned ID)

=cut

sub _ensure_index_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	if ( ! $self->_contains_index_of_id( $id ) ) {
		my $new_index = $self->_num_indices();
		$self->_set_index_of_id ( $id,        $new_index                               );
		$self->_push_id_of_index( $id                                                  );
		$self->_set_links_data  ( $new_index, Cath::Gemma::Scan::Impl::LinkList->new() );
	}
	return $self->_get_index_of_id( $id );
}

=head2 _active_indices

The sorted list of active indices

=cut

sub _active_indices {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [
		grep {
			defined( $self->_get_id_of_index( $ARG ) );
		} ( 0 .. ( $self->_num_indices() - 1 ) )
	];
}

=head2 _indices_and_score_of_lowest_score_result

Get the indices and score of the result in the matrix with the lowest score

Returns: [ index1, index2, score ] corresponding to the best result (where index1 and index2 are sorted numerically).

Clients probably want `ids_and_score_of_lowest_score_result` rather than this

=cut

sub _indices_and_score_of_lowest_score_result {
	state $check = compile(Object);
	my ($self) = $check->(@ARG);

	# If there are fewer than two entries then log a debug message and return an empty result
	if ( $self->count() < 2 ) {
		DEBUG "Cannot find ids_and_score_of_lowest_score_result() in this ScansData because count is " . $self->count();
		return [];
	}

	# Return the result with the lowest score
	# (where undef is compared as 'inf' so it will be treated as worse than all other scores)
	my $result = min_by {
		my $result = $ARG;
		$result->[2] // 'inf';
	}
	map {
		# Get the link from $id with the best score
		my $index = $ARG;
		my ( $other_index, $score ) = @{ $self->_get_index_and_score_of_lowest_score_of_index($index) };
		[ $index, $other_index, $score ];
	} @{ $self->_active_indices() };

	# bob
	return [( sort { $a <=> $b } ( $result->[0], $result->[1] ) ),$result->[-1]];
}

=head2 _get_index_and_score_of_lowest_score_of_index

Get the indices and score of the result with the lowest score
*to the cluster with the specified index*

Returns: [ index, score ] corresponding to the best result.

Clients probably want `get_id_and_score_of_lowest_score_of_id` or
`ids_and_score_of_lowest_score_result` rather than this.

=cut

sub _get_index_and_score_of_lowest_score_of_index {
	state $check = compile( Object, Int );
	my ( $self, $index ) = $check->(@ARG);

	# Check this is large enough
	if ( $self->count() < 2 ) {
		confess 'Cannot get index and score of lowest score of index when there are fewer than two items that are linked ' . Dumper($self) . ' ';
	}

	# Get *a copy of* the lowest score link from that index
	# (use a copy so that it can be modified without altering the original data)
	return dclone($self->_get_links_data($index)->get_idx_and_score_of_lowest_score_of_id( $self->_id_of_index() ));
}

=head2 _indices_and_score_results_below_eq_cutoff_for_active_index

Get all the (index1, index2, score) results below or equal to the specified cutoff
that are active according to the specified sorted list of active indices

=cut

sub _indices_and_score_results_below_eq_cutoff_for_active_index {
	state $check = compile( Object, Num, Int );
	my ( $self, $cutoff, $active_link_list_idx ) = $check->(@ARG);

	# Check index is active
	if ( !defined( $self->_get_id_of_index($ARG) ) ) {
		confess '_indices_and_score_results_below_eq_cutoff_for_active_index() called with inactive index';
	}

	# For each of the index-and-score results below the specified cutoff in the specified LinkList,
	# add in the index of the link list and order the two indices
	return [
		map {
			[( sort { $a <=> $b } ( $active_link_list_idx, $ARG->[0] ) ),$ARG->[1],];
		} @{ $self->_get_links_data($active_link_list_idx)->all_index_and_score_results_below_eq_cutoff($self->_id_of_index(),$cutoff) }
	];
}

=head2 get_score_between

Get the score between the two clusters with the specified IDs

=cut

sub get_score_between {
	state $check = compile( Object, Str, Str );
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	my $index1 = $self->_checked_index_of_id( $id1 );
	my $index2 = $self->_checked_index_of_id( $id2 );
	return $self->_get_links_data( $index1 )->get_score_to( $index2 );
}

=head2 sorted_ids

Get a sorted list of the IDs

=cut

sub sorted_ids {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [ cluster_name_spaceship_sort( $self->ids() ) ];
}

=head2 add_separate_clusters

Add non-linked clusters for each of the 

=cut

sub add_separate_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	foreach my $id ( @$ids ) {
		$self->_ensure_index_of_id( $id );
	}
	return $self;
}

=head2 add_scan_entry

Add a single link (ie ID1, ID2 and score) to the matrix

This doesn't check whether a link has already been added between the specified items
so don't add the same link multiple times

=cut

sub add_scan_entry {
	state $check = compile( Object, Str, Str, Num );
	my ( $self, $id1, $id2, $score ) = $check->( @ARG );

	my $index1 = $self->_ensure_index_of_id( $id1 );
	my $index2 = $self->_ensure_index_of_id( $id2 );

	$self->_get_links_data( $index1 )->add_scan_entry( $index2, $score );
	$self->_get_links_data( $index2 )->add_scan_entry( $index1, $score );

	return $self;
}

=head2 remove

Remove the entry with the specified ID

=cut

sub remove {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	my $index = $self->_checked_index_of_id( $id );
	$self->_set_id_of_index   ( $index, undef );
	$self->_set_links_data    ( $index, undef );
	$self->_delete_index_of_id( $id           );
	return $self;
}

=head2 ids_and_score_of_lowest_score_result

Get the IDs and score of the pair with the lowest score

Returns: [ id1, id2, score ] for the best result (where id1 and id2 have been ordered with cluster_name_spaceship_sort)

=cut

sub ids_and_score_of_lowest_score_result {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $result = $self->_indices_and_score_of_lowest_score_result();

	return [
		cluster_name_spaceship_sort(
			$self->_get_id_of_index( $result->[ 0 ] ),
			$self->_get_id_of_index( $result->[ 1 ] ),
		),
		$result->[ -1 ]
	];
}

=head2 merge_pair

Create a new node with the specified ID by merging the two clusters with the specified IDs
and build the new cluster's scores to each of the other clusters by calling the specified
score_update_function for each other cluster with:

 * the score from the first  cluster to the other cluster
 * the score from the second cluster to the other cluster
 * the ID of the other cluster

=cut

sub merge_pair {
	state $check = compile( Object, Str, Str, Str, CodeRef );
	my ( $self, $merged_node_id, $id1, $id2, $score_update_function ) = $check->( @ARG );

	my $index1        = $self->_checked_index_of_id( $id1 );
	my $index2        = $self->_checked_index_of_id( $id2 );
	my $other_scores1 = $self->_get_links_data( $index1 )->get_laid_out_scores( $self->_num_indices() );
	my $other_scores2 = $self->_get_links_data( $index2 )->get_laid_out_scores( $self->_num_indices() );

	#
	my @new_clust_scores = grep {
		defined( $ARG->[ 1 ] )
	}
	map {
		my $other_idx    = $ARG;
		my $other_score1 = $other_scores1->[ $other_idx ];
		my $other_score2 = $other_scores2->[ $other_idx ];
		[
			$other_idx,
			$score_update_function->(
				$other_score1,
				$other_score2,
				$self->_get_id_of_index( $other_idx )
			)
		];
	}
	grep {
		(
			( $ARG != $index1 )
			&&
			( $ARG != $index2 )
			&&
			defined( $self->_get_id_of_index( $ARG ) )
		);
	} ( 0..$#$other_scores1 );

	my $index = $self->_ensure_index_of_id( $merged_node_id );
	$self->_set_links_data( $index, Cath::Gemma::Scan::Impl::LinkList->make_list( \@new_clust_scores ) );
	foreach my $new_clust_score ( @new_clust_scores ) {
		my ( $other_index, $other_score ) = @$new_clust_score;
		$self->_get_links_data( $other_index )->add_scan_entry( $index, $other_score );
	}

	$self->remove( $id1 );
	$self->remove( $id2 );

	return $self;
}

=head2 get_id_and_score_of_lowest_score_of_id

Get the IDs and score of the result with the lowest score
*to the cluster with the specified index*

Returns: [ id, score ] corresponding the best result

=cut

sub get_id_and_score_of_lowest_score_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	# Check this is large enough
	if ( $self->count() < 2 ) {
		confess 'Cannot get ID and score of lowest score of ID when there are fewer than two items that are linked ' . Dumper( $self ) . ' ';
	}

	# Get the index of the id in question and then get (a copy of) the lowest score link from that index
	my $best_result = $self->_get_index_and_score_of_lowest_score_of_index(
		$self->_get_index_of_id( $id )
	);

	# If the link isn't a null link, change its index back to an ID
	if ( defined( $best_result->[ 0 ] ) ) {
		$best_result->[ 0 ] = $self->_get_id_of_index( $best_result->[ 0 ] );
	}

	return $best_result;
}

=head2 all_indices_and_score_results_below_eq_cutoff

TODOCUMENT

Get all the (index1, index2, score) results below or equal to the specified cutoff
that are active according to the specified sorted list of active indices

=cut

sub all_indices_and_score_results_below_eq_cutoff {
	state $check = compile( Object, Num );
	my ( $self, $cutoff ) = $check->( @ARG );

	return [
		map {
			@{ $self->_indices_and_score_results_below_eq_cutoff_for_active_index( $cutoff, $ARG ) };
		} @{ $self->_active_indices() }
	];
}

=head2 ids_and_score_of_lowest_score_window

TODOCUMENT

TODO: This could be made more efficient: it doesn't have to find the results
      within the window in order (as at present), it could just find all
      the results in the window and then sort them at the end

=cut

sub ids_and_score_of_lowest_score_window {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my ( $index1, $index2, $score ) = @{ $self->_indices_and_score_of_lowest_score_result() };

	if ( ! defined( $score ) ) {
		confess ' ';
	}

	my $score_cutoff = evalue_window_ceiling( $score );

	my @initial_results = sort {
		( $a->[ 2 ] <=> $b->[ 2 ] )
		||
		( $a->[ 0 ] <=> $b->[ 0 ] )
		||
		( $a->[ 1 ] <=> $b->[ 1 ] )
	} @{ $self->all_indices_and_score_results_below_eq_cutoff( $score_cutoff ) };

	my %indices_seen_before;
	my @results;
	foreach my $result ( @initial_results ) {

		my ( $idx1, $idx2 ) = @$result;
		if ( ! defined( $indices_seen_before{ $idx1 } ) && ! defined( $indices_seen_before{ $idx2 } ) ) {
			push @results, $result;
			$indices_seen_before{ $idx1 } = 1;
			$indices_seen_before{ $idx2 } = 1;
		}
	}

	return [
		map {
			[
				$self->_get_id_of_index( $ARG->[ 0 ] ),
				$self->_get_id_of_index( $ARG->[ 1 ] ),
				$ARG->[ 2 ],
			];
		} @results
	];
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
			if ( $id1 lt $id2 || ! defined( $data->{ $id2 }->{ $id1 } ) ) {
				$new->add_scan_entry( $id1, $id2, $data_of_id1->{ $id2 } );
			}
		}
	}
	return $new;
}

1;
