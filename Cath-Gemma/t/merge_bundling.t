#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 13;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
use Cath::Gemma::Disk::GemmaDirSet; # ****** TEMPORARY ******
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler;
use Cath::Gemma::Util;

use lib $FindBin::Bin . '/lib';
use Cath::Gemma::Test;

my $sfam_id               = '3.30.70.1470';
my $data_base_dir         = path( $FindBin::Bin )->child( 'data', $sfam_id )->realpath();
my $starting_clusters_dir = $data_base_dir->child( 'starting_clusters' );
my $scans_dir             = $data_base_dir->child( 'scans'             );

my $windowed_bundler = new_ok( 'Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler' );

if ( Cath::Gemma::Test->bootstrap_is_on ) {
	Cath::Gemma::Test::bootstrap_hhsuite_scan_files_for_superfamily( $sfam_id );
}

my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_dir_and_starting_clusters_dir(
	$scans_dir,
	default_profile_build_type(),
	$starting_clusters_dir,
);

# # compass
# my @first_five_merges = (
# 	[
# 		[   '8',  '33', '6.20e-53' ],
# 		[  '30',  '31', '8.13e-52' ],
# 	],
# 	[
# 		[ '172', '174', '8.45e-49' ],
# 		[ '316', '338', '5.18e-48' ],
# 		[ '394', '398', '1.49e-47' ],
# 		[  '24',  '25', '1.26e-44' ],
# 		[ '339', '368', '5.77e-44' ],
# 		[ '520', '521', '1.37e-43' ],
# 		[ '399', '402', '4.97e-43' ],
# 		[ '401', '452', '7.65e-41' ],
# 	],
# 	[
# 		[ '393', '400', '9.57e-40' ],
# 		[  '81', '223', '1.86e-37' ],
# 		[ '396', '397', '4.79e-37' ],
# 		[ '451', '454', '9.16e-32' ],
# 		[   '9', '522', '5.32e-31' ],
# 	],
# 	[
# 		[ '299', '553', '1.27e-25' ],
# 		[  '44', '185', '9.83e-25' ],
# 	],
# 	[
# 		[ '369', '453', '1.55e-19' ],
# 		[ '302', '305', '2.46e-18' ],
# 		[ '337', '559', '4.38e-14' ],
# 		[  '77', '496', '9.73e-14' ],
# 	],
# 	[
# 		[  '26', '573', '2.22e-03' ],
# 	],
# );


# my @first_five_expected_query_scs_and_match_scs_entries = (
# 		[
# 		[
# 			[ qw/ 8 33 / ],
# 			[ qw/ 9 24 25 26 30 31 44 77 81 172 174 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 / ]
# 		],
# 		[
# 			[ qw/ 30 31 / ],
# 			[ qw/ 9 24 25 26 44 77 81 172 174 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 / ]
# 		],
# 	],
# 	[
# 		[
# 			[ qw/ 172 174 / ],
# 			[ qw/ 9 24 25 26 44 77 81 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 / ]
# 		],
# 		[
# 			[ qw/ 316 338 / ],
# 			[ qw/ 9 24 25 26 44 77 81 185 223 299 302 305 337 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_7cc053dac265b2c9f4c27b02e7a54005 / ]
# 		],
# 		[
# 			[ qw/ 394 398 / ],
# 			[ qw/ 9 24 25 26 44 77 81 185 223 299 302 305 337 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_7cc053dac265b2c9f4c27b02e7a54005 / ]
# 		],
# 		[
# 			[ qw/ 24 25 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 / ]
# 		],
# 		[
# 			[ qw/ 339 368 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 520 521 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 369 393 396 397 399 400 401 402 451 452 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 399 402 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 369 393 396 397 400 401 451 452 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 401 452 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 369 393 396 397 400 451 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 	],
# 	[
# 		[
# 			[ qw/ 393 400 / ],
# 			[ qw/ 9 26 44 77 81 185 223 299 302 305 337 369 396 397 451 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 81 223 / ],
# 			[ qw/ 9 26 44 77 185 299 302 305 337 369 396 397 451 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 396 397 / ],
# 			[ qw/ 9 26 44 77 185 299 302 305 337 369 451 453 454 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 451 454 / ],
# 			[ qw/ 9 26 44 77 185 299 302 305 337 369 453 496 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 		[
# 			[ qw/ 9 522 / ],
# 			[ qw/ 26 44 77 185 299 302 305 337 369 453 496 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 / ]
# 		],
# 	],
# 	[
# 		[
# 			[ qw/ 299 553 / ],
# 			[ qw/ 26 44 77 185 302 305 337 369 453 496 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 		[
# 			[ qw/ 44 185 / ],
# 			[ qw/ 26 77 302 305 337 369 453 496 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 	],
# 	[
# 		[
# 			[ qw/ 369 453 / ],
# 			[ qw/ 26 77 302 305 337 496 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_6d3a5f2d64040a89905d2c1e99ee9bd9 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 		[
# 			[ qw/ 302 305 / ],
# 			[ qw/ 26 77 337 496 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_6d3a5f2d64040a89905d2c1e99ee9bd9 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 		[
# 			[ qw/ 337 559 / ],
# 			[ qw/ 26 77 496 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_218c1d2b5d50103cd30b88d1cb33c225 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_6d3a5f2d64040a89905d2c1e99ee9bd9 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 		[
# 			[ qw/ 77 496 / ],
# 			[ qw/ 26 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_218c1d2b5d50103cd30b88d1cb33c225 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_6d3a5f2d64040a89905d2c1e99ee9bd9 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_ecc3c0e0db81ac4ab069e1f5e350f80c n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 	],
# 	[
# 		[
# 			[ qw/ 26 573 / ],
# 			[ qw/ 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_154518d61b989d789b285c5b1f9c91cd n0de_218c1d2b5d50103cd30b88d1cb33c225 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5c1e4de49d8575440b98077731e7a25f n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_6d3a5f2d64040a89905d2c1e99ee9bd9 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_be80fb175a8923af6c251dd7c3317276 n0de_bef38d6f08d965e81ac59747e3e2753d n0de_ecc3c0e0db81ac4ab069e1f5e350f80c n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
# 		],
# 	],
# );


# hhsearch
my @first_five_merges = (
[
	['30','31','1.5E-67'],
	['8','33','1.4E-65'],
	['172','174','1.5E-64'],
	['398','402','1.8E-63'],
	['316','338','2.3E-63'],
],
[
	['394','399','3.8E-60'],
	['81','573','2.3E-57'],
	['520','521','4.3E-57'],
	['339','368','1.7E-55'],
	['393','452','2E-55'],
	['400','401','2.1E-54'],
	['25','44','5.4E-53'],
],
[
	['396','397','1.3E-49'],
	['185','223','9.4E-49'],
],
[
	['451','453','3.3E-38'],
	['9','522','1.8E-37'],
],
[
	['299','553','1.4E-25'],
],
[
	['369','454','5.6E-20'],
	['24','77','8.7E-16'],
	['302','305','4.2E-14'],
]
);

# hhsearch
my @first_five_expected_query_scs_and_match_scs_entries = (
	[
		[
			['30','31'],
			['8','9','24','25','26','33','44','77','81','172','174','185','223','299','302','305','316','337','338','339','368','369','393','394','396','397','398','399','400','401','402','451','452','453','454','496','520','521','522','553','559','560','573']
		],
		[
			['8','33'],
			['9','24','25','26','44','77','81','172','174','185','223','299','302','305','316','337','338','339','368','369','393','394','396','397','398','399','400','401','402','451','452','453','454','496','520','521','522','553','559','560','573','n0de_0cd60efb5578cd967c3c23894f305800']
		],
		[
			['172','174'],
			['9','24','25','26','44','77','81','185','223','299','302','305','316','337','338','339','368','369','393','394','396','397','398','399','400','401','402','451','452','453','454','496','520','521','522','553','559','560','573','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800']
		],
		[
			['398','402'],
			['9','24','25','26','44','77','81','185','223','299','302','305','316','337','338','339','368','369','393','394','396','397','399','400','401','451','452','453','454','496','520','521','522','553','559','560','573','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_7cc053dac265b2c9f4c27b02e7a54005']
		],
		[
			['316','338'],
			['9','24','25','26','44','77','81','185','223','299','302','305','337','339','368','369','393','394','396','397','399','400','401','451','452','453','454','496','520','521','522','553','559','560','573','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_7cc053dac265b2c9f4c27b02e7a54005']
		]
	],
	[
		[
			['394','399'],
			['9','24','25','26','44','77','81','185','223','299','302','305','337','339','368','369','393','396','397','400','401','451','452','453','454','496','520','521','522','553','559','560','573','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_7cc053dac265b2c9f4c27b02e7a54005']
		],
		[
			['81','573'],
			['9','24','25','26','44','77','185','223','299','302','305','337','339','368','369','393','396','397','400','401','451','452','453','454','496','520','521','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_d03d7c78791bc59c912811717f9bd43e']
		],
		[
			['520','521'],
			['9','24','25','26','44','77','185','223','299','302','305','337','339','368','369','393','396','397','400','401','451','452','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_d03d7c78791bc59c912811717f9bd43e']
		],
		[
			['339','368'],
			['9','24','25','26','44','77','185','223','299','302','305','337','369','393','396','397','400','401','451','452','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_d03d7c78791bc59c912811717f9bd43e']
		],
		[
			['393','452'],
			['9','24','25','26','44','77','185','223','299','302','305','337','369','396','397','400','401','451','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_d03d7c78791bc59c912811717f9bd43e']
		],
		[
			['400','401'],
			['9','24','25','26','44','77','185','223','299','302','305','337','369','396','397','451','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e']
		],
		[
			['25','44'],
			['9','24','26','77','185','223','299','302','305','337','369','396','397','451','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e']
		]
	],
	[
		[
			['396','397'],
			['9','24','26','77','185','223','299','302','305','337','369','451','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8']
		],
		[
			['185','223'],
			['9','24','26','77','299','302','305','337','369','451','453','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8']
		]
	],
	[
		[
			['451','453'],
			['9','24','26','77','299','302','305','337','369','454','496','522','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8']
		],
		[
			['9','522'],
			['24','26','77','299','302','305','337','369','454','496','553','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_a81ab7e6ff3e45548c192593beb59de6','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8']
		]
	],
	[
		[
			['299','553'],
			['24','26','77','302','305','337','369','454','496','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_a81ab7e6ff3e45548c192593beb59de6','n0de_acac80c86123a461eb4d806a0df16d85','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8','n0de_fdc42b6b0ee16a2f866281508ef56730']
		]
	],
	[
		[
			['369','454'],
			['24','26','77','302','305','337','496','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_a81ab7e6ff3e45548c192593beb59de6','n0de_acac80c86123a461eb4d806a0df16d85','n0de_be80fb175a8923af6c251dd7c3317276','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_f0f6ba4b5e0000340312d33c212c3ae8','n0de_fdc42b6b0ee16a2f866281508ef56730']
		],
		[
			['24','77'],
			['26','302','305','337','496','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_a81ab7e6ff3e45548c192593beb59de6','n0de_acac80c86123a461eb4d806a0df16d85','n0de_be80fb175a8923af6c251dd7c3317276','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_d5db946b54859fa4fe021a74aa22461e','n0de_f0f6ba4b5e0000340312d33c212c3ae8','n0de_fdc42b6b0ee16a2f866281508ef56730']
		],
		[
			['302','305'],
			['26','337','496','559','560','n0de_013a006f03dbc5392effeb8f18fda755','n0de_0cd60efb5578cd967c3c23894f305800','n0de_154518d61b989d789b285c5b1f9c91cd','n0de_19265c17f8c7d2977b05556d6acb98fe','n0de_47cec49bb5b15cf1fc59b770e45f2dbc','n0de_4c8c76b39d294759a9000cbda3a6571a','n0de_4d90b6c22554db6b9aaee213d3cedcde','n0de_72d730cd771f0c34057130547a221709','n0de_7cc053dac265b2c9f4c27b02e7a54005','n0de_90cac4e176223ffb5776056e930e16aa','n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92','n0de_9fbe545a8997556d8534e616387c2a0b','n0de_a81ab7e6ff3e45548c192593beb59de6','n0de_acac80c86123a461eb4d806a0df16d85','n0de_be80fb175a8923af6c251dd7c3317276','n0de_d03d7c78791bc59c912811717f9bd43e','n0de_d5db946b54859fa4fe021a74aa22461e','n0de_f0f6ba4b5e0000340312d33c212c3ae8','n0de_fdc42b6b0ee16a2f866281508ef56730']
		]
	],
);


my @bundle_data;
my @windowed_bundle_data;

foreach my $ctr ( 0 .. 5 ) {
	my $bundle = $windowed_bundler->get_execution_bundle( $scans_data );

	push @bundle_data, $bundle;

	is_deeply(
		$bundle,
		$first_five_merges[ $ctr ],
		'Merges at step ' . $ctr . ' are as expected',
	);

	my $windowed_bundle = $windowed_bundler->get_query_scs_and_match_scs_list_of_bundle( $scans_data );

	push @windowed_bundle_data, $windowed_bundle;

	is_deeply(
		$windowed_bundle,
		$first_five_expected_query_scs_and_match_scs_entries[ $ctr ],
		'Query starting clusters and match starting clusters for merges at step ' . $ctr . ' are as expected'
	);

	# # my @sue = map {
	# # 	[ @$ARG[ 1, 2 ] ];
	# # } @{ $scans_data->no_op_merge_pairs( [ map { [ @$ARG[ 0, 1 ] ] } @$bundle ] ) };
	# # my $sue = $windowed_bundler->get_query_scs_and_match_scs_list_of_bundle( $scans_data );
	# my $sue = $windowed_bundler->make_work_batch_list_of_query_scs_and_match_scs_list(
	# 	$scans_data,
	# 	Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir_and_project(
	# 		path( '/tmp/gd' ),
	# 		'3.30.70.1470'
	# 	)
	# );
	# # use DDP coloured => 1;
	# use Data::Dumper;
	# warn Dumper( $sue );

	my $merge_result = $scans_data->merge_pairs_without_new_scores( [ map { [ @$ARG[ 0, 1 ] ] } @$bundle ] );
}

if ( Cath::Gemma::Test->bootstrap_is_on ) {
	use Data::Dumper;
	local $Data::Dumper::Indent=0;
	local $Data::Dumper::Varname='first_five_merges';
	local $Data::Dumper::Varname='first_five_expected_query_scs_and_match_scs_entries';
}

