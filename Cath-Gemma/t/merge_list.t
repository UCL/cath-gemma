#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 4;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (test) (local)
use Test::Exception;

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
		"1	2	4	2.3\n4	3	5	5.6\n",
		'to_tracefile_string() works'
	);
	is(
		make_simple_merge_list_with_non_numeric_ids()->to_tracefile_string(),
		"working_1	working_2	1	2.3\n1	working_3	2	5.6\n",
		'to_tracefile_string() works with non-numeric IDs'
	);
};
