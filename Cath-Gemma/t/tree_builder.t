#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;

# Core (test)
use Test::More tests => 12;
use v5.10;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Standard     qw/ Str            /;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Executor::LocalExecutor;

# Cath::Gemma Test
use Cath::Gemma::Test;

BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder'    ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder'     ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder' ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder'       ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::PureTreeBuilder'            ) }
BEGIN { use_ok( 'Cath::Gemma::TreeBuilder::WindowedTreeBuilder'        ) }

# Prep some useful data
# my $superfamily                = '1.20.5.200';
my $superfamily                = '3.30.70.1470';
my $data_base_dir              = path( $FindBin::Bin )->child( '/data' )->child( $superfamily )->realpath();
my $tracefiles_dir             = $data_base_dir->child( 'tracefiles' );
my $executor                   = Cath::Gemma::Executor::LocalExecutor->new();
my $gemma_dir_set              = Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir( $data_base_dir );
my $starting_clusters          = $gemma_dir_set->get_starting_clusters();

# Define a function for testing a specific TreeBuilder
my $test_tree_builder_fn = sub {
	state $check = compile( Str );
	my ( $tree_builder_name ) = $check->( @ARG );

	# Test the new
	my $tree_builder = new_ok( $tree_builder_name );

	# Build a tree and write it to a tempfile
	my $merge_list   = $tree_builder->build_tree(
		$executor,
		$starting_clusters,
		$gemma_dir_set,
	);
	my $got_file = Path::Tiny->tempfile();
	$merge_list->write_to_tracefile( $got_file );

	# Determine the file containing the expected output
	my $expected_file = $tracefiles_dir->child( $superfamily . '.' . $tree_builder->name() );

	# Compare the files
	file_matches(
		$got_file,
		$expected_file,
		'TreeBuilder generates MergeList that when output to a tracefile, matches expected'
	);
};

# Test each of the TreeBuilders
foreach my $tree_builder_name ( qw/
                                   Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder
                                   Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder
                                   Cath::Gemma::TreeBuilder::PureTreeBuilder
                                   Cath::Gemma::TreeBuilder::WindowedTreeBuilder
                                   / ) {
	subtest
		'TreeBuilder ' . $tree_builder_name . ' builds the expected tree (ie MergeList)',
		\&$test_tree_builder_fn,
		$tree_builder_name
}
