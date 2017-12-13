package Cath::Gemma::TreeBuilder::WindowedTreeBuilder;

use strict;
use warnings;

# Core
use English         qw/ -no_match_vars /;


# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils qw/ first_index    /;

with ( 'Cath::Gemma::TreeBuilder' );

=head2 id_flip

TODOCUMENT

=cut

sub id_flip {
	my ( $prev_ids, $id1, $id2 ) = @ARG;

	my $index1 = ( scalar( @$prev_ids ) > 0 ) ? ( first_index { $ARG eq $id1 } @$prev_ids ) : undef;
	my $index2 = ( scalar( @$prev_ids ) > 0 ) ? ( first_index { $ARG eq $id2 } @$prev_ids ) : undef;

	return
		(
			( defined( $index1 ) &&   defined( $index2 ) && ( $index2 < $index1 ) )
			||
			( defined( $index1 ) && ! defined( $index2 ) )
		)
		? ( $id2, $id1 )
		: ( $id1, $id2 );
}

=head2 name

TODOCUMENT

=cut

sub name {
	return "windowed";
}

=head2 build_tree

TODOCUMENT

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $self, $executor, $starting_clusters, $gemma_dir_set, $compass_profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	my $really_bad_score = 100000000;
	my %scores;

	my @nodenames_and_merges;

	my $num_merge_batches = 0;
	while ( $scans_data->count() > 1 ) {
		my $ids_and_score_list = $scans_data->ids_and_score_of_lowest_score_window();

		foreach my $ids_and_score ( @$ids_and_score_list ) {
			my ( $id1, $id2, $score ) = @$ids_and_score;

			( $id1, $id2 ) = id_flip( [ map { $ARG->[ 0 ] } @nodenames_and_merges ], $id1, $id2 );

			my $merged_starting_clusters = $scans_data->merge_remove( $id1, $id2, $clusts_ordering );
			my $other_ids                = $scans_data->sorted_ids();
			my $merged_node_id           = $scans_data->add_starting_clusters_group_by_id( $merged_starting_clusters );

			push @nodenames_and_merges, [
				$merged_node_id,
				Cath::Gemma::Tree::Merge->new(
					mergee_a => $id1,
					mergee_b => $id2,
					score    => $score // $really_bad_score,
				),
			];

			if ( $scans_data->count() == 1 ) {
				last;
			}

			my $new_scan_data = Cath::Gemma::Tool::CompassScanner->build_and_scan_merge_cluster_against_others(
				$executor->exes(), # TODO: Fix this appalling violation of OO principles
				$merged_starting_clusters,
				$other_ids,
				$gemma_dir_set,
				$compass_profile_build_type,
			)->{ result };

			$scans_data->add_scan_data( $new_scan_data );
		}
		# warn "\n";
		++$num_merge_batches;
	}

	warn "Number of merge-batches : $num_merge_batches\n";

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;
