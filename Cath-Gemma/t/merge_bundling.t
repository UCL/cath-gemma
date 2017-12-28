#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 12;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
use Cath::Gemma::Disk::GemmaDirSet; # ****** TEMPORARY ******
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler;
use Cath::Gemma::Util;

my $data_base_dir         = path( $FindBin::Bin )->child( '/data/3.30.70.1470/' )->realpath();
my $starting_clusters_dir = $data_base_dir->child( 'starting_clusters' );
my $scans_dir             = $data_base_dir->child( 'scans'             );

my $windowed_bundler = Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler->new();

my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_dir_and_starting_clusters_dir(
	$scans_dir,
	default_compass_profile_build_type(),
	$starting_clusters_dir,
);

my @first_five_merges = (
	[
		[  '30',   '31', '8.13e-52' ],
	],
	[
		[   '8',   '33', '1.41e-49' ],
		[ '172',  '174', '8.45e-49' ],
		[ '394',  '398', '2.08e-47' ],
		[ '299',  '316', '4.84e-45' ],
		[  '81',  '573', '1.04e-44' ],
		[  '24',   '25', '1.05e-44' ],
		[ '339',  '368', '5.77e-44' ],
		[ '520',  '521', '1.37e-43' ],
		[ '399',  '402', '4.97e-43' ],
		[ '401',  '452', '1.20e-41' ],
	],
	[
		[ '393',  '400', '2.11e-40' ],
		[ '185',  '223', '7.53e-39' ],
		[ '396',  '397', '3.42e-37' ],
		[ '451',  '454', '9.16e-32' ],
		[   '9',  '522', '5.32e-31' ],
	],
	[
		[ '338',  '553', '5.48e-23' ],
	],
	[
		[ '369',  '453', '1.55e-19' ],
		[  '44',   '77', '2.13e-19' ],
		[ '302',  '305', '2.88e-18' ],
		[ '337',  '559', '4.38e-14' ],
	],

	[
		[  '26',  '496', '8.76e-10' ],
	],
);

my @first_five_expected_query_scs_and_match_scs_entries = (
	[
		[
			[ qw / 30 31 / ],
			[ qw / 8 9 24 25 26 33 44 77 81 172 174 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 / ]
		]
	],
	[
		[
			[ qw / 8 33 / ],
			[ qw / 9 24 25 26 44 77 81 172 174 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_0cd60efb5578cd967c3c23894f305800 / ]
		],
		[
			[ qw / 172 174 / ],
			[ qw / 9 24 25 26 44 77 81 185 223 299 302 305 316 337 338 339 368 369 393 394 396 397 398 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 / ]
		],
		[
			[ qw / 394 398 / ],
			[ qw / 9 24 25 26 44 77 81 185 223 299 302 305 316 337 338 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_7cc053dac265b2c9f4c27b02e7a54005 / ]
		],
		[
			[ qw / 299 316 / ],
			[ qw / 9 24 25 26 44 77 81 185 223 302 305 337 338 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 573 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 / ]
		],
		[
			[ qw / 81 573 / ],
			[ qw / 9 24 25 26 44 77 185 223 302 305 337 338 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 24 25 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 339 368 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 339 368 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 369 393 396 397 399 400 401 402 451 452 453 454 496 520 521 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 520 521 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 369 393 396 397 399 400 401 402 451 452 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 399 402 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 369 393 396 397 400 401 451 452 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 401 452 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 369 393 396 397 400 451 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		]
	],
	[
		[
			[ qw / 393 400 / ],
			[ qw / 9 26 44 77 185 223 302 305 337 338 369 396 397 451 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 185 223 / ],
			[ qw / 9 26 44 77 302 305 337 338 369 396 397 451 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 396 397 / ],
			[ qw / 9 26 44 77 302 305 337 338 369 451 453 454 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 451 454 / ],
			[ qw / 9 26 44 77 302 305 337 338 369 453 496 522 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		],
		[
			[ qw / 9 522 / ],
			[ qw / 26 44 77 302 305 337 338 369 453 496 553 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab / ]
		]
	],
	[
		[
			[ qw / 338 553 / ],
			[ qw / 26 44 77 302 305 337 369 453 496 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		]
	],
	[
		[
			[ qw / 369 453 / ],
			[ qw / 26 44 77 302 305 337 496 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_0ee711a9a85500572fe5689c7f237f48 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		],
		[
			[ qw / 44 77 / ],
			[ qw / 26 302 305 337 496 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_0ee711a9a85500572fe5689c7f237f48 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		],
		[
			[ qw / 302 305 / ],
			[ qw / 26 337 496 559 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_0ee711a9a85500572fe5689c7f237f48 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_d03a857a23b5285736c4d55e0bb067c8 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		],
		[
			[ qw / 337 559 / ],
			[ qw / 26 496 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_0ee711a9a85500572fe5689c7f237f48 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_218c1d2b5d50103cd30b88d1cb33c225 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_d03a857a23b5285736c4d55e0bb067c8 n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		]
	],
	[
		[
			[ qw / 26 496 / ],
			[ qw / 560 n0de_013a006f03dbc5392effeb8f18fda755 n0de_0cd60efb5578cd967c3c23894f305800 n0de_0ee711a9a85500572fe5689c7f237f48 n0de_11aa2c49f420e123fad1441d98885541 n0de_19265c17f8c7d2977b05556d6acb98fe n0de_218c1d2b5d50103cd30b88d1cb33c225 n0de_3319d5b4972ecd1e0cba6acfb7f23645 n0de_47cec49bb5b15cf1fc59b770e45f2dbc n0de_52c5c034f18dc9a9eddcbd9cbc918b40 n0de_5bac427b6d0dae364f7a769ca1606f4c n0de_5f3b875badec2a4a89be13ee15b48e7a n0de_72d730cd771f0c34057130547a221709 n0de_7cc053dac265b2c9f4c27b02e7a54005 n0de_7fa7266122b8200a441d7e70fdbc671f n0de_90cac4e176223ffb5776056e930e16aa n0de_9393cfd3fa42eb16fe3fe3ebfa9afa92 n0de_d03a857a23b5285736c4d55e0bb067c8 n0de_ecc3c0e0db81ac4ab069e1f5e350f80c n0de_f83630579d055dc5843ae693e7cdafe0 n0de_fd40e8c5a0f3f52d24bb19bc49a853ab n0de_fdc42b6b0ee16a2f866281508ef56730 / ]
		]
	]
);

foreach my $ctr ( 0 .. 5 ) {
	my $bundle = $windowed_bundler->get_execution_bundle( $scans_data );

	is_deeply(
		$bundle,
		$first_five_merges[ $ctr ],
		'Merges at step ' . $ctr . ' are as expected',
	);

	is_deeply(
		$windowed_bundler->get_query_scs_and_match_scs_list_of_bundle( $scans_data ),
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
