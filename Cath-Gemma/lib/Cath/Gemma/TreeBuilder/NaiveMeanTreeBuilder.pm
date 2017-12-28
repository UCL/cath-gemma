package Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder;

use strict;
use warnings;

# Core
use English  qw/ -no_match_vars /;
use Storable qw/ dclone         /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

with ( 'Cath::Gemma::TreeBuilder' );

=head2 name

TODOCUMENT

=cut

sub name {
	return "naive_mean";
}

=head2 build_tree

TODOCUMENT

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $self, $executor, $starting_clusters, $gemma_dir_set, $compass_profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	my $orig_scans_data = bless( dclone( $scans_data ), ref( $scans_data ) );

	my @nodenames_and_merges;
	while ( $scans_data->count() > 1 ) {
		my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score_or_arbitrary() };

		my $merged_node_id = $scans_data->merge_add_with_unweighted_geometric_mean_score(
			$id1,
			$id2,
			$orig_scans_data,
			$clusts_ordering
		);

		push @nodenames_and_merges, [
			$merged_node_id,
			Cath::Gemma::Tree::Merge->new(
				mergee_a => $id1,
				mergee_b => $id2,
				score    => $score,
			),
		];
	}

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;
