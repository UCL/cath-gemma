package Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English  qw/ -no_match_vars /;


# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;


# Non-core (local)
use Type::Params       qw/ compile Invocant           /;
use Types::Path::Tiny  qw/ Path                       /;
use Types::Standard    qw/ ArrayRef Object Str        /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaProfileType
/;

use Cath::Gemma::Util qw/ profile_scanner_class_from_type /;

with ( 'Cath::Gemma::TreeBuilder' );

=head2 name

TODOCUMENT

=cut

sub name {
	return "naive_mean_of_best";
}

=head2 build_tree

TODOCUMENT

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $self, $exes, $executor, $starting_clusters, $gemma_dir_set, $profile_build_type, $clusts_ordering, $scans_data ) = ( @ARG );

	my $really_bad_score = 100000000;
	my %scores;

	my @nodenames_and_merges;

	my $scanner_class = profile_scanner_class_from_type( $profile_build_type );

	while ( $scans_data->count() > 2 ) {
		my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score_or_arbitrary() };

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
				score    => $score,
			),
		];

		my $new_scan_data = $scanner_class->build_and_scan_merge_cluster_against_others(
			$exes,
			$merged_starting_clusters,
			$other_ids,
			$gemma_dir_set,
			$profile_build_type,
		)->{ result };

		$scans_data->add_scan_data( $new_scan_data );
	}

	my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score_or_arbitrary() };
	push @nodenames_and_merges, [
		'final_merge',
		Cath::Gemma::Tree::Merge->new(
			mergee_a => $id1,
			mergee_b => $id2,
			score    => $score,
		),
	];

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;
