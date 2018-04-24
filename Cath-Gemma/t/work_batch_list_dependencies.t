#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 1;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatchList;

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

