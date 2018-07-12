package Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder - Build a tree using only the initial all-vs-all scores by setting merged clusters scores as the lowest of the mergees' scores

=cut

use strict;
use warnings;

# Core
use English  qw/ -no_match_vars /;


# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 2;




with ( 'Cath::Gemma::TreeBuilder' );

=head2 name

TODOCUMENT

=cut

sub name {
	return "naive_lowest";
}

=head2 build_tree

TODOCUMENT

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $self, $exes, $executor, $starting_clusters, $gemma_dir_set, $profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	my @nodenames_and_merges;
	while ( $scans_data->count() > 1 ) {
		my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score_or_arbitrary() };
		my $merged_node_id = $scans_data->merge_pair_using_lowest_score( $id1, $id2, $clusts_ordering );
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
