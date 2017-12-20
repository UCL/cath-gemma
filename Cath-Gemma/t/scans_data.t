#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;
use Storable qw/ dclone /;

# Core (test)
use Test::More tests => 10;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Util;

{
	my $data_base_dir         = path( $FindBin::Bin . '/data/1.20.5.200' )->realpath();
	my $starting_clusters_dir = $data_base_dir->child( 'starting_clusters' );
	my $scans_dir             = $data_base_dir->child( 'scans'             );
	my $tree_file             = $data_base_dir->child( '1.20.5.200.trace'  );

	my $tree       = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tree_file );
	my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_starting_clusters_and_dir(
		$scans_dir,
		default_compass_profile_build_type(),
		$tree->starting_clusters(),
	);

	my $id_and_score_a = $scans_data->ids_and_score_of_lowest_score();
	is( $id_and_score_a->[ 0 ], '1',        'Highest score in data involves starting cluster 1' );
	is( $id_and_score_a->[ 1 ], '2',        'Highest score in data involves starting cluster 2' );
	is( $id_and_score_a->[ 2 ], '2.47e-15', 'Highest score in data has score 2.47e-15'          );

	my $premerge_scans_data = dclone( $scans_data );
	my $merge_1_2_dry_run   = $scans_data->no_op_merge_pair( qw/ 1 2 / );
	my $expected_merge_1_2  = [ id_of_starting_clusters( [ qw/ 1 2 / ] ), [ qw/ 1 2 / ], [ qw/ 3 4 / ] ];
	is_deeply( $premerge_scans_data, $scans_data, 'no_op_merge_pair() does not change ScansData' );
	is_deeply( $merge_1_2_dry_run, $expected_merge_1_2, 'this test' );

	my $merge_1_2_real = $scans_data->merge_pair( qw/ 1 2 / );
	is_deeply( $merge_1_2_real, $expected_merge_1_2, 'this other test' );

	my $id_and_score_b = $scans_data->ids_and_score_of_lowest_score();
	is( $id_and_score_b->[ 0 ], '3',        'Highest score in data involves starting cluster 3' );
	is( $id_and_score_b->[ 1 ], '4',        'Highest score in data involves starting cluster 4' );
	is( $id_and_score_b->[ 2 ], '5.19e-09', 'Highest score in data has score 5.19e-09'          );
}

{
	my $scans_data = Cath::Gemma::Scan::ScansData->new(
		starting_clusters_of_ids => Cath::Gemma::StartingClustersOfId->new_from_starting_clusters( [ 1, 2, 3 ] ),
		scans => {
			1 => {
				2 => 5.0,
				3 => 5.0,
			},
			2 => {
				1 => 5.0,
				3 => 7.0,
			},
			3 => {
				1 => 5.0,
				2 => 7.0,
			},
		},
	);

	is_deeply(
		$scans_data->get_id_and_score_of_lowest_score_of_id( '1', { '2' => 1 } ),
		[ '3', 5.0 ],
		'Respects $excluded_ids, even if an excluded ID gets the same score as the answer and comes earlier',
	);
}
