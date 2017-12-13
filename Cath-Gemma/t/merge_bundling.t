use strict;
use warnings;

# Core (test)
use Test::More tests => 6;

# Core
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Find non-core lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Find Cath::Gemma lib directory using FindBin
use lib $FindBin::Bin . '/lib';

# Cath
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

my @expecteds = (
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

foreach my $ctr ( 0 .. 5 ) {
	my $bundle = $windowed_bundler->get_execution_bundle( $scans_data );
	is_deeply( $bundle, $expecteds[ $ctr ], 'BLARGH ' . $ctr );

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

	my $merge_result = $scans_data->merge_pairs( [ map { [ @$ARG[ 0, 1 ] ] } @$bundle ] );
}
