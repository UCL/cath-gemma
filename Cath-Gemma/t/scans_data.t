use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

use Test::More tests => 3;

# Non-core (local)
use Path::Tiny;

# Cath
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Util;

my $data_base_dir         = path( $FindBin::Bin . '/data/1.20.5.200' )->realpath();
my $starting_clusters_dir = $data_base_dir->child( 'starting_clusters' );
my $scans_dir             = $data_base_dir->child( 'scans'             );
my $tree_file             = $data_base_dir->child( '1.20.5.200.trace'  );

my $tree       = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tree_file );
my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_starting_clusters_and_dir(
	$tree->starting_clusters(),
	$scans_dir,
	default_compass_profile_build_type(),
);

my $id_and_score = $scans_data->ids_and_score_of_lowest_score();

is( $id_and_score->[ 0 ], '1',        'Highest score in data involves starting cluster 1' );
is( $id_and_score->[ 1 ], '2',        'Highest score in data involves starting cluster 2' );
is( $id_and_score->[ 2 ], '1.45e-14', 'Highest score in data has score 1.45e-14'          );
