#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English    qw/ -no_match_vars /;
use FindBin;
use List::Util qw/ max            /;
use Storable   qw/ dclone         /;

# Core (test)
use Test::More tests => 14;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Non-core (test) (local)
use Test::Exception;

# Cath::Gemma
use Cath::Gemma::Scan::Impl::LinkMatrix;

sub make_example_score_of_id_of_id {
	return {
		item_1 => {
			item_2 => 5.0,
			item_3 => 5.0,
			item_4 => 1.0,
		},
		item_2 => {
			item_1 => 5.0,
			item_3 => 7.0,
			item_4 => 2.0,
		},
		item_3 => {
			item_1 => 5.0,
			item_2 => 7.0,
			item_4 => 3.0,
		},
		item_4 => {
			item_1 => 1.0,
			item_2 => 2.0,
			item_3 => 3.0,
		},
	};
}

subtest 'constructs_from_no_arguments' => sub {
	new_ok( 'Cath::Gemma::Scan::Impl::LinkMatrix' );
};

subtest 'builds_correctly_from_score_of_id_of_id' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	isa_ok( $scans_data, 'Cath::Gemma::Scan::Impl::LinkMatrix' );
};

subtest 'builds_correctly_from_score_of_id_of_id_with_few_scores' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( { item_1 => {}, item_2 => { item_1 => 5.0 } } );
	isa_ok( $scans_data, 'Cath::Gemma::Scan::Impl::LinkMatrix' );
	is( $scans_data->get_score_between( 'item_1', 'item_2' ), 5.0, 'Initial score between item_1 and item_2 is 5.0' );
	is( $scans_data->get_score_between( 'item_2', 'item_1' ), 5.0, 'Initial score between item_2 and item_1 is 5.0' );
};

subtest 'sorted_ids_returns_expected' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	is_deeply(
		$scans_data->sorted_ids(),
		[ qw / item_1 item_2 item_3 item_4 / ]
	);
};

subtest 'check_and_ensure_index_of_id_work' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	ok     ( defined( $scans_data->_checked_index_of_id( 'item_1' ) ) );
	ok     ( defined( $scans_data->_checked_index_of_id( 'item_2' ) ) );
	ok     ( defined( $scans_data->_checked_index_of_id( 'item_3' ) ) );
	ok     ( defined( $scans_data->_checked_index_of_id( 'item_4' ) ) );
	dies_ok(    sub { $scans_data->_checked_index_of_id( 'madeup' ) } );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'item_1' ) ) );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'item_2' ) ) );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'item_3' ) ) );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'item_4' ) ) );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'madeup' ) ) );
	ok     ( defined( $scans_data->_checked_index_of_id( 'madeup' ) ) );
};

subtest 'add_separate_starting_clusters_works' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	dies_ok(    sub { $scans_data->_checked_index_of_id( 'new_thing_1' ) } );
	dies_ok(    sub { $scans_data->_checked_index_of_id( 'new_thing_2' ) } );
	is     ( $scans_data->add_separate_starting_clusters( [ qw/ new_thing_1 new_thing_2 / ] ), $scans_data, 'add_separate_starting_clusters() returns the LinkMatrix object' );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'new_thing_1' ) ) );
	ok     ( defined( $scans_data->_ensure_index_of_id ( 'new_thing_2' ) ) );
};

subtest 'gets_score_between_ids' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	$scans_data->add_separate_starting_clusters( [ qw/ otherx / ] );

	is( $scans_data->get_score_between( 'item_1', 'item_2' ),   5.0, 'Initial score between item_1 and item_2 is 5.0' );
	is( $scans_data->get_score_between( 'item_1', 'item_3' ),   5.0, 'Initial score between item_1 and item_3 is 5.0' );
	is( $scans_data->get_score_between( 'item_1', 'item_4' ),   1.0, 'Initial score between item_1 and item_4 is 1.0' );
	is( $scans_data->get_score_between( 'item_2', 'item_1' ),   5.0, 'Initial score between item_2 and item_1 is 5.0' );
	is( $scans_data->get_score_between( 'item_2', 'item_3' ),   7.0, 'Initial score between item_2 and item_3 is 7.0' );
	is( $scans_data->get_score_between( 'item_2', 'item_4' ),   2.0, 'Initial score between item_2 and item_4 is 2.0' );
	is( $scans_data->get_score_between( 'item_3', 'item_1' ),   5.0, 'Initial score between item_3 and item_1 is 5.0' );
	is( $scans_data->get_score_between( 'item_3', 'item_2' ),   7.0, 'Initial score between item_3 and item_2 is 7.0' );
	is( $scans_data->get_score_between( 'item_3', 'item_4' ),   3.0, 'Initial score between item_3 and item_4 is 3.0' );
	is( $scans_data->get_score_between( 'item_4', 'item_1' ),   1.0, 'Initial score between item_4 and item_1 is 1.0' );
	is( $scans_data->get_score_between( 'item_4', 'item_2' ),   2.0, 'Initial score between item_4 and item_2 is 2.0' );
	is( $scans_data->get_score_between( 'item_4', 'item_3' ),   3.0, 'Initial score between item_4 and item_3 is 3.0' );
	is( $scans_data->get_score_between( 'item_1', 'otherx' ), undef, 'Request for absent score returns undef'         );
};

subtest 'add_scan_entry_works' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );
	$scans_data->add_separate_starting_clusters( [ qw/ otherx / ] );

	is( $scans_data->get_score_between( 'item_1', 'otherx'       ), undef,       'Request for absent score returns undef'          );
	is( $scans_data->add_scan_entry   ( 'item_1', 'otherx', 20.0 ), $scans_data, 'add_scan_entry() returns the LinkMatrix object'       );
	is( $scans_data->get_score_between( 'item_1', 'otherx'       ), 20.0,        'Request for newly added score returns the score' );
};

subtest 'removes_correctly' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );

	is( $scans_data->remove( 'item_2' ), $scans_data, 'remove() returns the LinkMatrix object' );
	is_deeply(
		$scans_data->sorted_ids(),
		[ qw / item_1 item_3 item_4 / ]
	);
};

subtest 'merge_pair_works' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );

	$scans_data->merge_pair( qw/ combi item_2 item_4 /, sub { 123.0; } );
	is_deeply(
		$scans_data->sorted_ids(),
		[ qw / item_1 item_3 combi / ]
	);
	is( $scans_data->get_score_between( 'item_1', 'combi' ), 123.0, 'Merged node has score of 123 to item_1' );
	is( $scans_data->get_score_between( 'item_3', 'combi' ), 123.0, 'Merged node has score of 123 to item_3' );
};

subtest 'get_id_and_score_of_lowest_score_of_id__works' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );

	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_1'                  ), [ 'item_4', 1.0 ] );
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_2'                  ), [ 'item_4', 2.0 ] );
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_3'                  ), [ 'item_4', 3.0 ] );
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_4'                  ), [ 'item_1', 1.0 ] );
	dies_ok  ( sub { $scans_data->get_id_and_score_of_lowest_score_of_id( 'combi'                   ) }, 'Dies on request for lowest score of absent node' );
};

subtest 'get_id_and_score_of_lowest_score_of_id__works_after_merge' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new_from_score_of_id_of_id( make_example_score_of_id_of_id() );

	$scans_data->merge_pair( qw/ combi item_2 item_4 /, sub { 123.0; } );
	
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_1' ), [ 'item_3',   5.0 ] );
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_3' ), [ 'item_1',   5.0 ] );
	is_deeply(       $scans_data->get_id_and_score_of_lowest_score_of_id( 'combi'  ), [ 'item_1', 123.0 ] );
	dies_ok  ( sub { $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_2' ) }, 'Dies on request for lowest score of absent node' );
	dies_ok  ( sub { $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_4' ) }, 'Dies on request for lowest score of absent node' );
};

subtest 'get_id_and_score_of_lowest_score_of_id__dies_if_smaller_than_two' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new();
	dies_ok( sub { $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_1' ) }, 'Dies on request for lowest score of absent node' );
	$scans_data->add_separate_starting_clusters( [ 'item_1' ] );
	dies_ok( sub { $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_1' ) }, 'Dies on request for lowest score of absent node' );
};

subtest 'get_id_and_score_of_lowest_score_of_id__returns_undef_inf_if_no_scores' => sub {
	my $scans_data = Cath::Gemma::Scan::Impl::LinkMatrix->new();
	$scans_data->add_separate_starting_clusters( [ 'item_1', 'item_2' ] );
	is_deeply( $scans_data->get_id_and_score_of_lowest_score_of_id( 'item_1' ), [ undef, 'inf' ], 'Returns [ undef, inf ] on request for lowest score of node with no scores' );
};
