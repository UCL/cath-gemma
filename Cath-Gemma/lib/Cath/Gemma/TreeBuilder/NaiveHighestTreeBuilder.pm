package Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder;

use strict;
use warnings;

# Core
use English  qw/ -no_match_vars /;


# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;




with ( 'Cath::Gemma::TreeBuilder' );

=head2 name

=cut

sub name {
	return "naive_highest";
}

=head2 build_tree

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $self, $executor, $starting_clusters, $gemma_dir_set, $compass_profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	my $really_bad_score = 100000000;
	my %scores;

	my @nodenames_and_merges;

	while ( $scans_data->count() > 1 ) {
		my $result = $scans_data->ids_and_score_of_lowest_score();
		if ( ! defined( $result ) ) {
			my @ids = sort( keys( %{ $scans_data->starting_clusters_of_ids() } ) );
			$result = [ $ids[ 0 ], $ids[ 1 ], $really_bad_score ];
		}
		my ( $id1, $id2, $score ) = @$result;

		my $merged_node_id = $scans_data->merge_add_with_score_of_highest( $id1, $id2, $clusts_ordering );

		push @nodenames_and_merges, [
			$merged_node_id,
			Cath::Gemma::Tree::Merge->new(
				mergee_a => $id1,
				mergee_b => $id2,
				score    => ( $score // $really_bad_score ),
			),
		];
	}

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;