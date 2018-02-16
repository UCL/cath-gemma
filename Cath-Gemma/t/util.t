#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;
use List::Util  qw/ min    /;
use Time::HiRes qw/ usleep /;

# Core (test)
use Test::More tests => 11;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Time::Seconds;

# Cath::Gemma
use Cath::Gemma::Util;

subtest 'time_fn() works ok' => sub {
	my $a = time_fn( sub { my $val = shift; usleep( 100 ); return $val; }, 'oooh' );

	is    ( $a->{ result   },  'oooh',                        'Takes arguments and returns result'    );
	isa_ok( $a->{ duration },  'Time::Seconds',               'Returns a Time::Seconds duration'      );
	ok    ( $a->{ duration } >= Time::Seconds->new( 0.0001 ), 'Sleeping 0.1 ms takes at least 0.1 ms' );
	ok    ( $a->{ duration } <  Time::Seconds->new( 0.001  ), 'Sleeping 0.1 ms takes less than 1 ms'  );
};

subtest 'mergee_is_starting_cluster() works ok' => sub {
	ok(   mergee_is_starting_cluster(   0      ), '0 is a starting cluster' );
	ok( ! mergee_is_starting_cluster( [ 0, 1 ] ), '[ 0, 1 ] is not a starting cluster' );
};

subtest 'batch_into_n() works ok' => sub {
	is_deeply( [ batch_into_n( 3, 1, 2, 3, 4, 5, 6, 7, 8 ) ], [ [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7, 8 ] ], 'Batching 1..8 into threes works as expected' );
};

subtest 'evalue_window_ceiling() / evalue_window_floor()' => sub {
	is( evalue_window_ceiling( 1.2e-15 ), 1e-10, 'evalue_window_ceiling() calculates correctly' );
	is( evalue_window_floor  ( 1.2e-15 ), 1e-20, 'evalue_window_floor  () calculates correctly' );
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
