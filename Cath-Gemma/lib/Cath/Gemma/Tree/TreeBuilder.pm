package Cath::Gemma::Tree::TreeBuilder;

use strict;
use warnings;

# Core
use Carp               qw/ confess              /;
use English            qw/ -no_match_vars       /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use strictures 1;

# Non-core (local)
use Type::Params       qw/ compile Invocant     /;
use Types::Path::Tiny  qw/ Path                 /;
use Types::Standard    qw/ ArrayRef Str         /;

# Cath
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Scan::ScansData;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Types qw/
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 build_tree

=cut

sub build_tree {
	state $check = compile( Invocant, CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskGemmaDirSet, Path );
	my ( $proto, $exes, $starting_clusters, $gemma_dir_set, $working_dir ) = $check->( @ARG );

	my %scores;

	# Ensure all starting clusters have profiles
	foreach my $starting_cluster ( @$starting_clusters ) {
		my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
			$exes,
			[ $starting_cluster ],
			$gemma_dir_set->profile_dir_set(),
			$working_dir,
		);
	}

	# Ensure scans are in place for all-vs-all scan of starting clusters
	my $initial_scans = Cath::Gemma::Tree::MergeList->inital_scans_of_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my $result = Cath::Gemma::Tool::CompassScanner->compass_scan_to_file(
			$exes,
			[ $initial_scan->[ 0 ] ],
			$initial_scan->[ 1 ],
			$gemma_dir_set,
			$working_dir,
		);
	}

	my $scans_data = Cath::Gemma::Scan::ScansData->new_from_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my ( $query_id, $match_cluster_ids ) = @$initial_scan;
		my $filename  = $gemma_dir_set->scan_filename_of_cluster_ids( [ $query_id ], $match_cluster_ids );
		$scans_data->add_scan_data( Cath::Gemma::Scan::ScanData->read_from_file( $filename ) );
	}

	my $merges = Cath::Gemma::Tree::MergeList->new();

	while ( $scans_data->count() > 2 ) {
		my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score() };
		$merges->push( Cath::Gemma::Tree::Merge->new(
			mergee_a => $id1,
			mergee_b => $id2,
			score    => $score,
		) );

		my $merged_starting_clusters = $scans_data->merge( $id1, $id2 );
		my $other_ids                = $scans_data->sorted_ids();

		$scans_data->add_node_of_starting_clusters( $merged_starting_clusters );

		my $new_scan_data = Cath::Gemma::Tool::CompassScanner->build_and_scan_merge_cluster_against_others(
			$exes,
			$merged_starting_clusters,
			$other_ids,
			$gemma_dir_set,
			$working_dir,
		)->{ result };

		# use Data::Dumper;
		# warn Dumper( [ $scans_data, $merged_starting_clusters, $other_ids ] ) . ' ';

		$scans_data->add_scan_data( $new_scan_data );

		# my $new_scan_filename = $gemma_dir_set->scan_filename_of_cluster_ids( [ $id1, $id2 ], [ $scans_data->ids() ] );
		# $scans_data->add_scan_data( Cath::Gemma::Scan::ScanData->read_from_file( $new_scan_filename ) );

		# use Data::Dumper;
		# warn Dumper( $merges ) . ' ';
	}

	my ( $id1, $id2, $score ) = @{ $scans_data->ids_and_score_of_lowest_score() };
	$merges->push( Cath::Gemma::Tree::Merge->new(
		mergee_a => $id1,
		mergee_b => $id2,
		score    => $score,
	) );

	# use Data::Dumper;
	# warn Dumper( $merges ) . ' ';
	return $merges;
}

1;
