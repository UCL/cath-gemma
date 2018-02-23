#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;
use List::Util          qw/ min    /;
use Time::HiRes         qw/ usleep /;

# Core (test)
use Test::More tests => 26;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy  /;
use Path::Tiny;
use Time::Seconds;

# Non-core (test) (local)
use Test::Exception;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Util;

# Cath::Gemma Test
use Cath::Gemma::Test;

Log::Log4perl->easy_init( { level => $ERROR } );

subtest 'time_fn() works ok' => sub {
	my $a = time_fn( sub { my $val = shift; usleep( 100 ); return $val; }, 'oooh' );

	is    ( $a->{ result   },  'oooh',                        'Takes arguments and returns result'    );
	isa_ok( $a->{ duration },  'Time::Seconds',               'Returns a Time::Seconds duration'      );
	ok    ( $a->{ duration } >= Time::Seconds->new( 0.0001 ), 'Sleeping 0.1 ms takes at least 0.1 ms' );
	ok    ( $a->{ duration } <  Time::Seconds->new( 0.001  ), 'Sleeping 0.1 ms takes less than 1 ms'  );
};

# run_and_time_filemaking_cmd() is tested in run_and_time_filemaking_cmd.t

subtest 'mergee_is_starting_cluster() works ok' => sub {
	ok(   mergee_is_starting_cluster(   0      ), '0 is a starting cluster' );
	ok( ! mergee_is_starting_cluster( [ 0, 1 ] ), '[ 0, 1 ] is not a starting cluster' );
};

subtest 'batch_into_n() works ok' => sub {
	is_deeply( [ batch_into_n( 3, 1, 2, 3, 4, 5, 6, 7, 8 ) ], [ [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7, 8 ] ], 'Batching 1..8 into threes works as expected' );
};

subtest 'cluster_name_spaceship_sort()' => sub {
	my @src_names          = ( qw/ clst_12 clst_10 clst_2 clst_99 clst_101 clst_102 clst_11 clst_100 clst_1 / );
	my @sorted_clust_names = cluster_name_spaceship_sort( @src_names );
	my @expected           = ( qw/ clst_1 clst_2 clst_10 clst_11 clst_12 clst_99 clst_100 clst_101 clst_102 / );
	is_deeply( \@sorted_clust_names, \@expected, 'cluster_name_spaceship_sort() sorts as expected' );
};

subtest 'combine_starting_cluster_names()' => sub {
	is_deeply(
		combine_starting_cluster_names( [ qw/ clst_101 clst_99 / ], [ qw/ clst_100 clst_98 / ], 'tree_df_ordering' ),
		[ qw/ clst_101 clst_99 clst_100 clst_98  / ]
	);
	is_deeply(
		combine_starting_cluster_names( [ qw/ clst_101 clst_99 / ], [ qw/ clst_100 clst_98 / ], 'simple_ordering'  ),
		[ qw/ clst_98  clst_99 clst_100 clst_101 / ]
	);
	is_deeply(
		combine_starting_cluster_names( [ qw/ clst_101 clst_99 / ], [ qw/ clst_100 clst_98 / ],                    ),
		[ qw/ clst_98  clst_99 clst_100 clst_101 / ]
	);
};

subtest 'combine_starting_cluster_names' => sub {
	is_deeply( combine_starting_cluster_names( [ 1, 3 ], [ 2, 4 ]                     ), [ 1, 2, 3, 4 ], 'combine_starting_cluster_names() returns as expected' );
	is_deeply( combine_starting_cluster_names( [ 1, 3 ], [ 2, 4 ], 'simple_ordering'  ), [ 1, 2, 3, 4 ], 'combine_starting_cluster_names() returns as expected' );
	is_deeply( combine_starting_cluster_names( [ 1, 3 ], [ 2, 4 ], 'tree_df_ordering' ), [ 1, 3, 2, 4 ], 'combine_starting_cluster_names() returns as expected' );
};

subtest 'generic_id_of_clusters' => sub {
	is( generic_id_of_clusters( [ 'my_clust_1'               ]    ), 'becc8eb32454b8d75b45a2d745473026', 'generic_id_of_clusters() returns as expected' );
	is( generic_id_of_clusters( [ 'my_clust_1'               ], 0 ), 'becc8eb32454b8d75b45a2d745473026', 'generic_id_of_clusters() returns as expected' );
	is( generic_id_of_clusters( [ 'my_clust_1'               ], 1 ), 'my_clust_1',                       'generic_id_of_clusters() returns as expected' );

	is( generic_id_of_clusters( [ 'my_clust_1', 'my_clust_2' ]    ), '4501c47c831144d7311bbdf6da7f5d84', 'generic_id_of_clusters() returns as expected' );
	is( generic_id_of_clusters( [ 'my_clust_1', 'my_clust_2' ], 0 ), '4501c47c831144d7311bbdf6da7f5d84', 'generic_id_of_clusters() returns as expected' );
	is( generic_id_of_clusters( [ 'my_clust_1', 'my_clust_2' ], 1 ), '4501c47c831144d7311bbdf6da7f5d84', 'generic_id_of_clusters() returns as expected' );
};

subtest 'get_starting_clusters_of_starting_cluster_dir' => sub {
	my $geoff = get_starting_clusters_of_starting_cluster_dir( test_superfamily_starting_cluster_dir( '1.20.5.200' ) );

	is_deeply(
		get_starting_clusters_of_starting_cluster_dir( test_superfamily_starting_cluster_dir( '1.20.5.200' ) ),
		[ 1, 2, 3, 4 ],
		'get_starting_clusters_of_starting_cluster_dir() returns as expected'
	);
	is_deeply(
		get_starting_clusters_of_starting_cluster_dir( test_data_dir()->child( 'dir_with_starting_clusters_and_silly_files' ) ),
		[ 1, 2, 3, 4 ],
		'get_starting_clusters_of_starting_cluster_dir() returns as expected'
	);
};

subtest 'guess_if_running_on_sge' => sub {
	lives_ok(
		sub { guess_if_running_on_sge(); },
		'guess_if_running_on_sge() does not die'
	);
};

subtest 'make_atomic_write_file' => sub {
	subtest 'does atomic writing for specified template' => sub {
		# Get a non-existent temporary file
		my $out_file = make_non_existent_temp_file();
		ok( ! -e $out_file  );

		# Create an atomic file and and write some data to it
		my $atomic_file     = make_atomic_write_file( { file => "$out_file", template => '.atomic_template.XXXXXXXXXX' } );
		my $atomic_filename = $atomic_file->filename();
		path( $atomic_filename )->spew( 'test_string' );

		# Check that the atomic file is non-empty and the destination file doesn't exist
		ok(   -s $atomic_filename );
		ok( ! -e $out_file        );

		# Commit the atomic file
		$atomic_file->commit();

		# Check that the destination file is non-empty and the atomic file doesn't exist
		# and the destination file's contents are correct
		ok(   -s $out_file        );
		ok( ! -e $atomic_filename );
		file_matches( $out_file, test_data_dir()->child( 'atomic_write_file.expected' ), 'Atomic file has been created' );

		# Clean up the files
		if ( -e $atomic_filename ) { $atomic_filename->remove(); }
		if ( -e $out_file        ) { $out_file       ->remove(); }
	};

	subtest 'no template' => sub {
		my $out_file = Path::Tiny->tempfile();
		my $atomic_file = make_atomic_write_file( { file => "$out_file" } );
		my $atomic_filename = $atomic_file->filename();
		like( $atomic_filename, qr/\.atmc_write\.host_.*\.pid_/, 'TODOC' );
	};
};

subtest 'id_of_clusters' => sub {
	dies_ok(
		sub { id_of_clusters( [                            ] ); },
		'id_of_clusters() dies as expected for zero ids'
	);
	is(
		id_of_clusters( [ 'my_clust_1'               ] ),
		'my_clust_1',
		'id_of_clusters() returns as expected for one id'
	);
	is(
		id_of_clusters( [ 'my_clust_1', 'my_clust_2' ] ),
		'n0de_4501c47c831144d7311bbdf6da7f5d84',
		'id_of_clusters() returns as expected for two ids'
	);
	is(
		id_of_clusters( [ 'my_clust_1', 'my_clust_2', 'my_clust_3' ] ),
		'n0de_b058f5b851e76e27506d4f7f1949d558',
		'id_of_clusters() returns as expected for two ids'
	);
};

subtest 'compass_profile_suffix' => sub {
	is( compass_profile_suffix(), '.prof', 'compass_profile_suffix() returns as expected' );
};

subtest 'default_compass_profile_build_type' => sub {
	is( default_compass_profile_build_type(), 'mk_compass_db', 'default_compass_profile_build_type() returns as expected' );
};

subtest 'default_temp_dir' => sub {
	is( default_temp_dir(), '/dev/shm', 'default_temp_dir() returns as expected' );
};

subtest 'evalue_window_ceiling() / evalue_window_floor()' => sub {
	is( evalue_window_ceiling( 1.2e-15 ), 1e-10, 'evalue_window_ceiling() calculates correctly' );
	is( evalue_window_floor  ( 1.2e-15 ), 1e-20, 'evalue_window_floor  () calculates correctly' );
};

subtest 'compass_scan_suffix' => sub {
	is( compass_scan_suffix(), '.scan', 'compass_scan_suffix() returns as expected' );
};

subtest 'default_clusts_ordering' => sub {
	is( default_clusts_ordering(), 'simple_ordering', 'default_clusts_ordering() returns as expected' );
};

subtest 'alignment_profile_suffix' => sub {
	is( alignment_profile_suffix(), '.faa', 'alignment_profile_suffix() returns as expected' );
};

subtest 'alignment_filebasename_of_starting_clusters' => sub {
	is(
		alignment_filebasename_of_starting_clusters( [ 'my_clust_1', 'my_clust_2' ] ),
		'n0de_4501c47c831144d7311bbdf6da7f5d84.faa',
		'alignment_filebasename_of_starting_clusters() returns as expected'
	);
};

subtest 'prof_file_of_prof_dir_and_aln_file' => sub {
	is(
		prof_file_of_prof_dir_and_aln_file( '/tmp', '/some/other/dir/my_clust_1.faa', default_compass_profile_build_type() ),
		'/tmp/my_clust_1.mk_compass_db.prof',
		'prof_file_of_prof_dir_and_aln_file() returns as expected'
	);
};

subtest 'prof_file_of_prof_dir_and_cluster_id' => sub {
	is(
		prof_file_of_prof_dir_and_cluster_id( '/tmp', 'my_clust_1', default_compass_profile_build_type() ),
		'/tmp/my_clust_1.mk_compass_db.prof',
		'prof_file_of_prof_dir_and_cluster_id() returns as expected'
	);
};

subtest 'raw_sequences_filename_of_starting_clusters' => sub {
	is(
		raw_sequences_filename_of_starting_clusters( [ 'my_clust_1', 'my_clust_2' ] ),
		'n0de_4501c47c831144d7311bbdf6da7f5d84.fa',
		'raw_sequences_filename_of_starting_clusters() returns as expected'
	);
};

subtest 'scan_filebasename_of_cluster_ids' => sub {
	is(
		scan_filebasename_of_cluster_ids( [ 'my_query' ], [ 'my_match_1', 'my_match_2' ], default_compass_profile_build_type(), ),
		'my_query.l1st_0fefca17cea83290bf5f9fa57c6f18c8.mk_compass_db.scan',
		'scan_filebasename_of_cluster_ids() returns as expected'
	);

	dies_ok(
		sub { scan_filebasename_of_cluster_ids( [            ], [ 'my_match_1', 'my_match_2' ], default_compass_profile_build_type(), ); },
		'scan_filebasename_of_cluster_ids() dies as expected with empty query'
	);
	dies_ok(
		sub { scan_filebasename_of_cluster_ids( [ 'my_query' ], [                            ], default_compass_profile_build_type(), ); },
		'scan_filebasename_of_cluster_ids() dies as expected with empty match'
	);
};

subtest 'scan_filename_of_dir_and_cluster_ids' => sub {
	is(
		scan_filename_of_dir_and_cluster_ids( '/tmp', [ 'my_query' ], [ 'my_match_1', 'my_match_2' ], default_compass_profile_build_type(), ),
		'/tmp/my_query.l1st_0fefca17cea83290bf5f9fa57c6f18c8.mk_compass_db.scan',
		'scan_filename_of_dir_and_cluster_ids() returns as expected'
	);
};

subtest 'time_seconds_to_sge_string()' => sub {
	is( time_seconds_to_sge_string( Time::Seconds->new(      0 ) ),  '00:00:00', 'time_seconds_to_sge_string() is correct on 0 seconds'           );
	is( time_seconds_to_sge_string( Time::Seconds->new(      1 ) ),  '00:00:01', 'time_seconds_to_sge_string() is correct on 1 second'            );

	is( time_seconds_to_sge_string( Time::Seconds->new(     59 ) ),  '00:00:59', 'time_seconds_to_sge_string() is correct on 1 minute - 1 second' );
	is( time_seconds_to_sge_string( Time::Seconds->new(     60 ) ),  '00:01:00', 'time_seconds_to_sge_string() is correct on 1 minute'            );
	is( time_seconds_to_sge_string( Time::Seconds->new(     61 ) ),  '00:01:01', 'time_seconds_to_sge_string() is correct on 1 minute + 1 second' );

	is( time_seconds_to_sge_string( Time::Seconds->new(   3599 ) ),  '00:59:59', 'time_seconds_to_sge_string() is correct on 1   hour - 1 second' );
	is( time_seconds_to_sge_string( Time::Seconds->new(   3600 ) ),  '01:00:00', 'time_seconds_to_sge_string() is correct on 1   hour'            );
	is( time_seconds_to_sge_string( Time::Seconds->new(   3601 ) ),  '01:00:01', 'time_seconds_to_sge_string() is correct on 1   hour + 1 second' );

	is( time_seconds_to_sge_string( Time::Seconds->new( 604799 ) ), '167:59:59', 'time_seconds_to_sge_string() is correct on 1   week - 1 second' );
	is( time_seconds_to_sge_string( Time::Seconds->new( 604800 ) ), '168:00:00', 'time_seconds_to_sge_string() is correct on 1   week'            );
	is( time_seconds_to_sge_string( Time::Seconds->new( 604801 ) ), '168:00:01', 'time_seconds_to_sge_string() is correct on 1   week + 1 second' );

	is(
		time_seconds_to_sge_string( Time::Seconds->new( 60 ) + Time::Seconds->new( 60 ) ),
		'00:02:00',
		'time_seconds_to_sge_string() is correct on 1 minute + 1 minute'
	);
};

subtest 'unique_by_hashing()' => sub {
	is_deeply( [ unique_by_hashing( 0                ) ], [ 0    ], 'unique_by_hashing() is correct on: 0'                );
	is_deeply( [ unique_by_hashing( 0, 0, 0          ) ], [ 0    ], 'unique_by_hashing() is correct on: 0, 0, 0'          );
	is_deeply( [ unique_by_hashing( 1, 2             ) ], [ 1, 2 ], 'unique_by_hashing() is correct on: 1, 2'             );
	is_deeply( [ unique_by_hashing( 1, 2, 2, 1, 2, 1 ) ], [ 1, 2 ], 'unique_by_hashing() is correct on: 1, 2, 2, 1, 2, 1' );
};
