#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Find non-core lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Test
use Test::More tests => 18;

# Non-core (local)
use Path::Tiny;

use lib path( "$FindBin::Bin/../lib" )->realpath()->stringify();

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Executor::LocalExecutor;

BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder'    ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder'     ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder' ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder'       ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::PureTreeBuilder'            ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::WindowedTreeBuilder'        ) }

my $data_base_dir              = path( $FindBin::Bin )->child( '/data/3.30.70.1470/' )->realpath();
my $executor                   = Cath::Gemma::Executor::LocalExecutor->new();
my $gemma_dir_set              = Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir( $data_base_dir );
my $starting_clusters          = $gemma_dir_set->get_starting_clusters();

foreach my $tree_builder_name ( qw/
                                   Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder
                                   Cath::Gemma::TreeBuilder::PureTreeBuilder
                                   Cath::Gemma::TreeBuilder::WindowedTreeBuilder
                                   / ) {
	my $tree_builder = new_ok( $tree_builder_name );

	my $merge_list   = $tree_builder->build_tree(
		$executor,
		$starting_clusters,
		$gemma_dir_set,
	);
	my $newick_string = $merge_list->to_newick_string();
	like( $newick_string, qr/\(520,/ );
}
