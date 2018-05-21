package Cath::Gemma::TreeBuilder::WindowedTreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder::WindowedTreeBuilder - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils     qw/ first_index    /;
use Log::Log4perl::Tiny qw/ :easy          /;

# Cath::Gemma
use Cath::Gemma::Executor::DirectExecutor;
use Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler;

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
	my ( $self, $exes, $executor, $starting_clusters, $gemma_dir_set, $profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	# TODONOW: Sort this out
	my $local_executor = Cath::Gemma::Executor::DirectExecutor->new();

	my $really_bad_score = 100000000;
	my %scores;

	my $merge_bundler = Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler->new();

	my $scanner_class = profile_scanner_class_from_type( $profile_build_type );


	my @nodenames_and_merges;

	my $num_merge_batches = 0;
	while ( $scans_data->count() > 1 ) {
		# my $ids_and_score_list = $scans_data->ids_and_score_of_lowest_score_window();

		# Get a list of work and then, if it's non-empty, wait for it to be run (potentially in child jobs)
		my $work_batch_list = $merge_bundler->make_work_batch_list_of_query_scs_and_match_scs_list( $scans_data, $gemma_dir_set, $profile_build_type );
		DEBUG
			'In '
			. __PACKAGE__
			. '->build_tree(), made a work_batch_list of '
			. $work_batch_list->num_steps()
			. ' steps, estimated to take up to '
			. $work_batch_list->estimate_time_to_execute()
			. ' seconds';
		if ( $work_batch_list->num_steps() > 0 ) {
			$executor->execute_batch_list( $work_batch_list, 'always_wait_for_complete' );
		}

		# Get a list of the merges
		my $ids_and_score_list = $merge_bundler->get_execution_bundle( $scans_data );

		foreach my $ids_and_score ( @$ids_and_score_list ) {
			my ( $id1, $id2, $score ) = @$ids_and_score;

			( $id1, $id2 ) = id_flip( [ map { $ARG->[ 0 ] } @nodenames_and_merges ], $id1, $id2 );

			my ( $merged_node_id, $merged_starting_clusters, $other_ids ) = @{ $scans_data->merge_pair_without_new_scores(
				$id1,
				$id2,
				$clusts_ordering
			) };


			push @nodenames_and_merges, [
				$merged_node_id,
				Cath::Gemma::Tree::Merge->new(
					mergee_a => $id1,
					mergee_b => $id2,
					score    => $score // $really_bad_score,
				),
			];

			DEBUG 'Adding merge between ' . $id1 . ' and ' . $id2;

			if ( $scans_data->count() == 1 ) {
				last;
			}

			my $response = $scanner_class->build_and_scan_merge_cluster_against_others(
				$exes,
				$merged_starting_clusters,
				$other_ids,
				$gemma_dir_set,
				$profile_build_type,
			);

			foreach my $check ( qw/ aln_file_already_present prof_file_already_present scan_file_already_present / ) {
				if ( ! $response->{ $check } ) {
					WARN
						  'In '
						. __PACKAGE__
						. '::build_tree(), failed to find file ( '
						. $check
						. ') that should already be present after previous execution (starting clusters: '
						. join( ', ', @$merged_starting_clusters )
						. '; other IDs: '
						. join( ', ', @$other_ids )
						. ')';
				}
			}

			$scans_data->add_scan_data( $response->{ result } );
		}
		# warn "\n";
		++$num_merge_batches;
	}

	INFO "Number of merge-batches : $num_merge_batches\n";

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;
