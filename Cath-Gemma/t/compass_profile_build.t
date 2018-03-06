#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 2;

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
use Cath::Gemma::Util;

# Don't flood this test with INFO messages
Log::Log4perl->easy_init( { level => $WARN } );

my $test_base_dir             = path( $FindBin::Bin . '/data' )->realpath();
my $build_compass_profile_dir = $test_base_dir            ->child( 'build_compass_profile'  );
my $prof_type                 = 'compass_wp_dummy_1st';

=head2 cmp_compass_profile_file

TODOCUMENT

=cut

sub cmp_compass_profile_type_against_file {
	state $check = compile( Str, Path, Path );
	my ( $assertion_name, $aln_file, $expected_prof ) = $check->( @ARG );

	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.compass_profile_build.XXXXXXXXXXX" );
	my $got_file     = prof_file_of_prof_dir_and_aln_file( $test_out_dir, $aln_file, $prof_type );

	# Build a profile file
	Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
		Cath::Gemma::Disk::Executables->new(),
		$aln_file,
		$test_out_dir,
		$prof_type,
	);

	# Compare it to expected
	file_matches(
		$got_file,
		$expected_prof,
		$assertion_name
	);

}

cmp_compass_profile_type_against_file(
	'Fixes profile built by old COMPASS by removing superfluous line',
	$build_compass_profile_dir->child( '3.20.20.120__2510.aln'  ),
	$build_compass_profile_dir->child( '3.20.20.120__2510.prof' ),
);

cmp_compass_profile_type_against_file(
	'TODOCUMENT',
	$build_compass_profile_dir->child( '3.20.20.120__6537.aln'  ),
	$build_compass_profile_dir->child( '3.20.20.120__6537.prof' ),
);
