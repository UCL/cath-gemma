use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 3;

# Non-core (local)
use Path::Tiny;

# Cath
use Cath::Gemma::Tree::MergeList;

my $merge_list = Cath::Gemma::Tree::MergeList->read_from_tracefile(
	path( $FindBin::Bin . '/data/trees/3.30.70.1470.trace'  )->realpath()
);

is_deeply(
	$merge_list->calc_heights(),
	[
		 1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
		 1,  2,  2,  2,  2,  3,  2,  2,  3,  2,
		 1,  2,  3,  2,  4,  4,  5,  5,  6,  1,
		 7,  3,  6,  7,  8,  9,  3,  3,  3, 10,
		 4, 11, 12, 13
	],
	'heights of tree match correct values'
);

is_deeply(
	$merge_list->calc_min_heights(),
	[
		 1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
		 1,  1,  2,  1,  1,  1,  1,  1,  1,  1,
		 1,  1,  1,  1,  2,  2,  2,  2,  1,  1,
		 1,  1,  1,  1,  2,  2,  2,  1,  1,  2,
		 2,  3,  2,  1
	],
	'min-heights of tree match correct values'
);

is_deeply(
	$merge_list->calc_depths(),
	[
		 6,  6,  6, 12,  8,  7, 10,  8, 10,  6,
		 8,  6,  7,  9,  7,  6,  5, 11,  6,  5,
		 6,  5, 10,  5,  5,  9,  4,  8,  3,  5,
		 2,  5,  7,  6,  5,  4,  4,  4,  4,  3,
		 3,  2,  1,  0
	],
	'depths of tree match correct values'
);
