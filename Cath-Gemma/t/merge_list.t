#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 15;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy  /;

# Non-core (test) (local)
use Test::Exception;
use Path::Tiny;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Executor::SpawnExecutor;
use Cath::Gemma::Util;

# Cath::Gemma Test
use Cath::Gemma::Test;

Log::Log4perl->easy_init( { level => $WARN } );

BEGIN{ use_ok( 'Cath::Gemma::Tree::MergeList') }

=head2 make_simple_merge_list

Make a simple example MergeList with only-numeric IDs for tests

=cut

sub make_simple_merge_list {
	return Cath::Gemma::Tree::MergeList->make_merge_list_from_simple_test_data( [
		[ qw/ 1   2 /, 2.3 ],
		[            -1, '3',  5.6 ],
	] );
}

=head2 make_simple_merge_list_with_non_numeric_ids

Make a simple example MergeList with non-numeric IDs for tests

=cut

sub make_simple_merge_list_with_non_numeric_ids {
	return Cath::Gemma::Tree::MergeList->make_merge_list_from_simple_test_data( [
		[ qw/ working_1   working_2 /, 2.3 ],
		[            -1, 'working_3',  5.6 ],
	] );
}

=head2 make_simple_merge_list_with_merge_node_ids

Make a simple example MergeList with IDs that look like merge_node_ IDs

=cut

sub make_simple_merge_list_with_merge_node_ids {
	return Cath::Gemma::Tree::MergeList->make_merge_list_from_simple_test_data( [
		[ qw/ working_1   merge_node_4 /, 2.3 ],
		[            -1, 'working_3'    , 5.6 ],
	] );
}

subtest 'make_merge_list_from_simple_test_data()' => sub {
	lives_ok( sub { make_simple_merge_list();                      }, 'making a simple MergeList does not die'                      );
	lives_ok( sub { make_simple_merge_list_with_non_numeric_ids(); }, 'making a simple MergeList with non-numeric IDs does not die' );
};

subtest 'starting_clusters()' => sub {
	is_deeply(
		make_simple_merge_list()->starting_clusters(),
		[ 1, 2, 3 ],
		'Gets correct starting_clusters()'
	);
	is_deeply(
		make_simple_merge_list_with_non_numeric_ids()->starting_clusters(),
		[ qw/ working_1 working_2 working_3 / ],
		'Gets correct starting_clusters() with non-numeric IDs'
	);
};

subtest 'to_tracefile_string()' => sub {
	is(
		make_simple_merge_list()->to_tracefile_string(),
		"1	2	merge_node_1	2.3\nmerge_node_1	3	merge_node_2	5.6\n",
		'to_tracefile_string() works'
	);
	is(
		make_simple_merge_list_with_non_numeric_ids()->to_tracefile_string(),
		"working_1	working_2	merge_node_1	2.3\nmerge_node_1	working_3	merge_node_2	5.6\n",
		'to_tracefile_string() works with non-numeric IDs'
	);
	is(
		make_simple_merge_list_with_merge_node_ids()->to_tracefile_string(),
		"working_1	merge_node_4	merge_node_5	2.3\nmerge_node_5	working_3	merge_node_6	5.6\n",
		'to_tracefile_string() works with merge-node IDs'
	);
};

subtest 'to_newick_string()' => sub {
	is(
		make_simple_merge_list()->to_newick_string(),
		'((1,2),3)',
		'to_newick_string() returns expected results'
	);
};

subtest 'write_to_newick_file()' => sub {
	my $got_file = Path::Tiny->tempfile();
	make_simple_merge_list()->write_to_newick_file( $got_file );

	file_matches(
		$got_file,
		test_data_dir()->child( 'expected_simple_newick_file' ),
		'write_to_newick_file() returns expected results'
	);
};

subtest 'starting_cluster_lists()' => sub {
	is_deeply(
		make_simple_merge_list()->starting_cluster_lists(),
		[ [ '1' ], [ '2' ], [ '3' ] ],
		'starting_cluster_lists() returns expected results'
	);
};

subtest 'merge_cluster_lists()' => sub {
	is_deeply(
		make_simple_merge_list()->merge_cluster_lists(),
		[ [ 1, 2 ], [ 1, 2, 3 ] ],
		'merge_cluster_lists() returns expected results'
	);
};

subtest 'initial_scans()' => sub {
	is_deeply(
		make_simple_merge_list()->initial_scans(),
		[ [ '1', [ '2', '3' ] ], [ '2', [ '3' ] ] ],
		'initial_scans() returns expected results'
	);
};

subtest 'initial_scan_lists()' => sub {
	is_deeply(
		make_simple_merge_list()->initial_scan_lists(),
		[ [ [ '1' ], [ '2', '3' ] ], [ [ '2' ], [ '3' ] ] ],
		'initial_scan_lists() returns expected results'
	);
};

subtest 'later_scans()' => sub {
	is_deeply(
		make_simple_merge_list()->later_scans(),
		[ [ 'n0de_c20ad4d76fe97759aa27a0c99bff6710', [ '3' ] ] ],
		'later_scans() returns expected results'
	);
};

subtest 'later_scan_lists()' => sub {
	is_deeply(
		make_simple_merge_list()->later_scan_lists(),
		[ [ [ 'n0de_c20ad4d76fe97759aa27a0c99bff6710' ], [ '3' ] ] ],
		'later_scan_lists() returns expected results'
	);
};

subtest 'starting_cluster_lists_for_all_alignments()' => sub {
	is_deeply(
		make_simple_merge_list()->starting_cluster_lists_for_all_alignments(),
		[ [ '1' ], [ '2' ], [ '3' ], [ 1, 2 ], [ 1, 2, 3 ] ],
		'starting_cluster_lists_for_all_alignments() returns expected results'
	);
};

subtest 'geometric_mean_score()' => sub {
	is(
		make_simple_merge_list()->geometric_mean_score(),
		3.58887168898527,
		'geometric_mean_score() returns expected results'
	);
};

# Unfortunately, this only catches the bad behaviour on an HPC setup because the SpawnLocalRunner runs synchronously
subtest 'by default, ensure_all_alignments() ensures all alignments before finishing' => sub {
	my $temp_out_dir      = cath_test_tempdir();
	my $superfamily       = '1.20.5.200';
	my $tracefile         = test_superfamily_tree_dir( $superfamily )->child( 'simple_ordering.mk_compass_db.windowed' )
	                                                                 ->child( 'tree.trace'                             );
	my $merge_list        = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tracefile );
	pop @{ $merge_list->merges() };
	pop @{ $merge_list->merges() };

	$merge_list->ensure_all_alignments(
		default_clusts_ordering(),
		Cath::Gemma::Disk::Executables->new(),
		Cath::Gemma::Executor::SpawnExecutor->new( 
			submission_dir => Path::Tiny->tempdir( 'cath-gemma.submission_dir.XXXXXXXX', CLEANUP => 1 ),
			child_tmp_dir => Path::Tiny->tempdir( 'cath-gemma.child_tmp_dir.XXXXXXXX', CLEANUP => 1 ),
		),
		Cath::Gemma::Disk::ProfileDirSet->new(
			aln_dir              => $temp_out_dir,
			prof_dir             => $temp_out_dir,
			base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
				base_dir => test_superfamily_data_dir( $superfamily )
			),
		),
	);
	foreach my $alignment_stem ( qw/ 1 2 n0de_c20ad4d76fe97759aa27a0c99bff6710 / ) {
		my $required_aln_file = $temp_out_dir->child( $alignment_stem . '.aln' );
		ok( -e $required_aln_file, 'Alignment file  ' . $required_aln_file . ' should have been created as soon as ensure_all_alignments() finishes' );
	}
};
