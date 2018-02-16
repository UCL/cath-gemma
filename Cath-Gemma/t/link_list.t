#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 7;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

BEGIN { use_ok( 'Cath::Gemma::Scan::Impl::LinkList' ) }

sub make_example_link_list_data {
	return [
		[ 4, 80.0 ],
		[ 7, 90.0 ],
		[ 2, 20.0 ],
		[ 9, 75.0 ],
	];
}

subtest 'constructs_from_no_arguments' => sub {
	new_ok( 'Cath::Gemma::Scan::Impl::LinkList' );
};

subtest 'get_score_to__returns_undef_on_new_empty' => sub {
	my $link_list = Cath::Gemma::Scan::Impl::LinkList->new();
	is( $link_list->get_score_to( 0 ), undef, 'get_score_to() on new empty returns undef' );
};


subtest 'can_add_and_retrieve_score' => sub {
	my $link_list = Cath::Gemma::Scan::Impl::LinkList->new();
	$link_list->add_scan_entry( 0, 20.0 );
	is( $link_list->get_score_to( 0 ), 20.0, 'get_score_to() on added link returns score' );
};

subtest 'make_list__works' => sub {
	my $link_list = Cath::Gemma::Scan::Impl::LinkList->make_list( make_example_link_list_data() );
	isa_ok( $link_list, 'Cath::Gemma::Scan::Impl::LinkList' );
	is( $link_list->get_score_to(  0 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  1 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  2 ),  20.0, 'make_list() sets the correct links'                );
	is( $link_list->get_score_to(  3 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  4 ),  80.0, 'make_list() sets the correct links'                );
	is( $link_list->get_score_to(  5 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  6 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  7 ),  90.0, 'make_list() sets the correct links'                );
	is( $link_list->get_score_to(  8 ), undef, 'make_list() does not initialise unspecified links' );
	is( $link_list->get_score_to(  9 ),  75.0, 'make_list() sets the correct links'                );
	is( $link_list->get_score_to( 10 ), undef, 'make_list() does not initialise unspecified links' );
};

subtest 'get_laid_out_scores__works' => sub {
	my $link_list = Cath::Gemma::Scan::Impl::LinkList->make_list( make_example_link_list_data() );

	is_deeply(
		$link_list->get_laid_out_scores( 12 ),
		[
			undef,
			undef,
			20.0,
			undef,
			80.0,
			undef,
			undef,
			90.0,
			undef,
			75.0,
			undef,
			undef
		],
		'get_laid_out_scores() returns the expected laid-out scores'
	);
};

subtest 'get_idx_and_score_of_lowest_score_of_id__works' => sub {
	my $link_list = Cath::Gemma::Scan::Impl::LinkList->make_list( make_example_link_list_data() );

	my @all       = (              ( 1 ) x 11 );
	is_deeply( $link_list->get_idx_and_score_of_lowest_score_of_id( \@all       ), [     2,  20.0 ],'Everything is active, correct lowest score and index' );

	my @all_but_2 = ( 1, 1, undef, ( 1 ) x  8 );
	is_deeply( $link_list->get_idx_and_score_of_lowest_score_of_id( \@all_but_2 ), [     9,  75.0 ],'All but 2 are active, correct lowest score and index' );

	my @none      = (                         );
	is_deeply( $link_list->get_idx_and_score_of_lowest_score_of_id( \@none      ), [ undef, 'inf' ],'Nothing is active the lowest score is inf to undef'   );
};
