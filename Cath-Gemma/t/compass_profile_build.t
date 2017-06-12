use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 1;

# Non-core (local)
use Path::Tiny;

# Cath Test
use Cath::Gemma::Test;

# Cath
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Util;

my $test_base_dir              = path( $FindBin::Bin . '/data' )->realpath();
my $build_compass_profile_dir  = $test_base_dir            ->child( 'build_compass_profile'  );
my $aln_file                   = $build_compass_profile_dir->child( '3.20.20.120__2510.faa'  );
my $expected_prof              = $build_compass_profile_dir->child( '3.20.20.120__2510.prof' );
my $test_out_dir               = cath_test_tempdir( TEMPLATE => "test.compass_profile_build.XXXXXXXXXXX" );
my $prof_type                  = 'compass_wp_dummy_1st';
my $got_file                   = prof_file_of_prof_dir_and_aln_file( $test_out_dir, $aln_file, $prof_type );

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
	'Fixes profile built by old COMPASS by removing superfluous line'
);

