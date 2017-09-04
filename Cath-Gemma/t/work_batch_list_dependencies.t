use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 1;

# Non-core (local)
# use Path::Tiny;
# use Type::Params      qw/ compile        /;
# use Types::Path::Tiny qw/ Path           /;
# use Types::Standard   qw/ Str            /;

# Cath Test
# use Cath::Gemma::Test;

# Cath
use Cath::Gemma::Compute::WorkBatchList;
# use Cath::Gemma::Disk::Executables;
# use Cath::Gemma::Tool::CompassProfileBuilder;
# use Cath::Gemma::Util;





# my $test_base_dir             = path( $FindBin::Bin . '/data' )->realpath();
# my $build_compass_profile_dir = $test_base_dir            ->child( 'build_compass_profile'  );
# my $prof_type                 = 'compass_wp_dummy_1st';

# =head2 cmp_compass_profile_file

# TODOCUMENT

# =cut

# sub cmp_compass_profile_type_against_file {
# 	state $check = compile( Str, Path, Path );
# 	my ( $assertion_name, $aln_file, $expected_prof ) = $check->( @ARG );

# 	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.compass_profile_build.XXXXXXXXXXX" );
# 	my $got_file     = prof_file_of_prof_dir_and_aln_file( $test_out_dir, $aln_file, $prof_type );

# 	# Build a profile file
# 	Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
# 		Cath::Gemma::Disk::Executables->new(),
# 		$aln_file,
# 		$test_out_dir,
# 		$prof_type,
# 	);

# 	# Compare it to expected
# 	file_matches(
# 		$got_file,
# 		$expected_prof,
# 		$assertion_name
# 	);

# }

# cmp_compass_profile_type_against_file(
# 	'Fixes profile built by old COMPASS by removing superfluous line',
# 	$build_compass_profile_dir->child( '3.20.20.120__2510.faa'  ),
# 	$build_compass_profile_dir->child( '3.20.20.120__2510.prof' ),
# );

# cmp_compass_profile_type_against_file(
# 	'TODOCUMENT',
# 	$build_compass_profile_dir->child( '3.20.20.120__6537.faa'  ),
# 	$build_compass_profile_dir->child( '3.20.20.120__6537.prof' ),
# );

my $count     = 38;
my $init_data = [
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[ 18, 17         ],
	[ 19, 18         ],
	[ 20, 19         ],
	[ 18, 17         ],
	[ 19, 18         ],
	[ 20, 19         ],
	[ 18, 17, 20, 21 ],
	[ 19, 18, 21, 22 ],
	[ 20, 19, 22, 23 ],
	[ 18, 17, 15, 14 ],
	[ 19, 18, 16, 15 ],
	[ 20, 19, 17, 16 ],
	[ 17, 18         ],
	[ 19, 18         ],
	[ 20, 19         ],
	[ 18, 17         ],
	[ 19, 18         ],
	[ 20, 19         ],
];

my $tidied_data = [
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[                ],
	[  2,  3         ],
	[  2,  3         ],
	[  2,  3         ],
	[  5,  6         ],
	[  5,  6         ],
	[  5,  6         ],
	[  5,  6,  8,  9 ],
	[  5,  6,  8,  9 ],
	[  5,  6,  8,  9 ],
	[ 11, 12, 14, 15 ],
	[ 11, 12, 14, 15 ],
	[ 11, 12, 14, 15 ],
	[ 14, 15         ],
	[ 14, 15         ],
	[ 14, 15         ],
	[ 17, 18         ],
	[ 17, 18         ],
	[ 17, 18         ],
];

is_deeply(
	Cath::Gemma::Compute::WorkBatchList->_init_tidy_dependencies( $init_data, $count ),
	$tidied_data
);

Cath::Gemma::Compute::WorkBatchList->_group_tidy_dependencies( $tidied_data );

my $grouped_data = [
	[ [  0,  1,  4,  7, 10, 13, 16, 19 ], [      ] ],
	[ [  2,  3                         ], [      ] ],
	[ [  5,  6                         ], [      ] ],
	[ [  8,  9                         ], [      ] ],
	[ [ 11, 12                         ], [      ] ],
	[ [ 14, 15                         ], [      ] ],
	[ [ 17, 18                         ], [      ] ],
	[ [ 20, 21, 22                     ], [ 1    ] ],
	[ [ 23, 24, 25                     ], [ 2    ] ],
	[ [ 26, 27, 28                     ], [ 2, 3 ] ],
	[ [ 29, 30, 31                     ], [ 4, 5 ] ],
	[ [ 32, 33, 34                     ], [ 5    ] ],
	[ [ 35, 36, 37                     ], [ 6    ] ],
];

