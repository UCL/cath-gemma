#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 3;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Path::Tiny   qw/ Path           /;
use Types::Standard     qw/ Str            /;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath Test
use Cath::Gemma::Test;

# Cath::Gemma
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Types qw/ CathGemmaCompassProfileType /;

# Don't flood this test with INFO messages
Log::Log4perl->easy_init( { level => $WARN } );

=head2 cmp_compass_profile_type_against_file

TODOCUMENT

=cut

sub cmp_compass_profile_type_against_file {
	state $check = compile( Str, CathGemmaCompassProfileType, Path, Path );
	my ( $assertion_name, $compass_profile_type, $alignment_file, $expected_file ) = $check->( @ARG );

	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.compass_profile_types.XXXXXXXXXXX" );

	my $got_filename = Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
		Cath::Gemma::Disk::Executables->new(),
		$alignment_file,
		$test_out_dir,
		$compass_profile_type,
	)->{ out_filename };

	file_matches(
		$got_filename,
		$expected_file,
		$assertion_name,
	);
}

my $test_base_dir          = path( $FindBin::Bin . '/data' )->realpath();
my $compass_prof_types_dir = $test_base_dir->child( 'compass_profile_types' );
my $alignment_file         = $compass_prof_types_dir->child( '1.10.150.120__1767.faa' );

SKIP: {
	# Skip this because compass_wp_dummy_1st can give different results when run identically on different machines. Eg:
	#
	#     echo '>A\nA\n' > /tmp/dummy.input
	#     ~/cath-gemma/Cath-Gemma/tools/compass/compass_wp_245_fixed -g 0.50001 -i /tmp/dummy.input -j ~/cath-gemma/Cath-Gemma/t/data/compass_profile_types/1.10.150.120__1767.faa -p1 /tmp/dummy.prof -p2 /tmp/1.10.150.120__1767.prof
	#
	# can give different results (as in the numbers inside the resulting profile differ)
	skip 'compass_wp_dummy_1st can give different results when run identically on different machines', 1;
	cmp_compass_profile_type_against_file(
		'Building a COMPASS model with type "compass_wp_dummy_1st" generates the expected file',
		'compass_wp_dummy_1st',
		$alignment_file,
		$compass_prof_types_dir->child( '1.10.150.120__1767.compass_wp_dummy_1st.prof' ),
	);
}

SKIP: {
	# Skip this because compass_wp_dummy_2nd can give different results when run identically on different machines (eg kingkong)
	skip 'compass_wp_dummy_2nd can give different results when run identically on different machines', 1;
	cmp_compass_profile_type_against_file(
		'Building a COMPASS model with type "compass_wp_dummy_2nd" generates the expected file',
		'compass_wp_dummy_2nd',
		$alignment_file,
		$compass_prof_types_dir->child( '1.10.150.120__1767.compass_wp_dummy_2nd.prof' ),
	);
}

cmp_compass_profile_type_against_file(
	'Building a COMPASS model with type "mk_compass_db" generates the expected file',
	'mk_compass_db',
	$alignment_file,
	$compass_prof_types_dir->child( '1.10.150.120__1767.mk_compass_db.prof'        ),
);

