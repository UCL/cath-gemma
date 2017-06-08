package Cath::Gemma::TreeBuilder::PureTreeBuilder;

use strict;
use warnings;

# Core
use Carp               qw/ confess                    /;
use English            qw/ -no_match_vars             /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params       qw/ compile Invocant           /;
use Types::Path::Tiny  qw/ Path                       /;
use Types::Standard    qw/ ArrayRef Bool Optional Str /;

# Cath
use Cath::Gemma::Scan::ScansData;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Types qw/
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

with ( 'Cath::Gemma::TreeBuilder' );

=head2 name

=cut

sub name {
	return "pure";
}

=head2 build_tree

Params checked in Cath::Gemma::TreeBuilder

=cut

sub build_tree {
	my ( $proto, $executor, $starting_clusters, $gemma_dir_set, $compass_profile_build_type, $use_depth_first, $scans_data ) = ( @ARG );

	my $really_bad_score = 100000000;
	my %scores;

	my @nodenames_and_merges;

	while ( $scans_data->count() > 2 ) {
		my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score() };

		my $merged_starting_clusters = $scans_data->merge_remove( $id1, $id2, $use_depth_first );
		my $other_ids                = $scans_data->sorted_ids();
		my $merged_node_id           = $scans_data->add_node_of_starting_clusters( $merged_starting_clusters );

		push @nodenames_and_merges, [
			$merged_node_id,
			Cath::Gemma::Tree::Merge->new(
				mergee_a => $id1,
				mergee_b => $id2,
				score    => $score // $really_bad_score,
			),
		];

		my $new_scan_data = Cath::Gemma::Tool::CompassScanner->build_and_scan_merge_cluster_against_others(
			$executor->exes(), # TODO: Fix this appalling violation of OO principles
			$merged_starting_clusters,
			$other_ids,
			$gemma_dir_set,
			$compass_profile_build_type,
		)->{ result };

		$scans_data->add_scan_data( $new_scan_data );
	}

	my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score() };
	push @nodenames_and_merges, [
		'final_merge',
		Cath::Gemma::Tree::Merge->new(
			mergee_a => $id1,
			mergee_b => $id2,
			score    => $score // $really_bad_score,
		),
	];

	return Cath::Gemma::Tree::MergeList->build_from_nodenames_and_merges( \@nodenames_and_merges );
}

1;
