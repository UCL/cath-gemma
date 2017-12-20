#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 22;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Time::Seconds;

# Cath::Gemma
use Cath::Gemma::Util;

# evalue_window_ceiling() / evalue_window_floor()
{
	is( evalue_window_ceiling( 1.2e-15 ), 1e-10, 'evalue_window_ceiling() calculates correctly' );
	is( evalue_window_floor  ( 1.2e-15 ), 1e-20, 'evalue_window_floor  () calculates correctly' );
}

# cluster_name_spaceship_sort()
{
	my @src_names          = ( qw/ clst_12 clst_10 clst_2 clst_99 clst_101 clst_102 clst_11 clst_100 clst_1 / );
	my @sorted_clust_names = cluster_name_spaceship_sort( @src_names );
	my @expected           = ( qw/ clst_1 clst_2 clst_10 clst_11 clst_12 clst_99 clst_100 clst_101 clst_102 / );
	is_deeply( \@sorted_clust_names, \@expected, 'cluster_name_spaceship_sort() sorts as expected' );
}

# combine_starting_cluster_names()
{
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
}

# unique_by_hashing()
{
	is_deeply( [ unique_by_hashing( 0                ) ], [ 0    ], 'unique_by_hashing() is correct on: 0'                );
	is_deeply( [ unique_by_hashing( 0, 0, 0          ) ], [ 0    ], 'unique_by_hashing() is correct on: 0, 0, 0'          );
	is_deeply( [ unique_by_hashing( 1, 2             ) ], [ 1, 2 ], 'unique_by_hashing() is correct on: 1, 2'             );
	is_deeply( [ unique_by_hashing( 1, 2, 2, 1, 2, 1 ) ], [ 1, 2 ], 'unique_by_hashing() is correct on: 1, 2, 2, 1, 2, 1' );
}

# time_seconds_to_sge_string()
{
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
}
