#!/usr/bin/env perl

use strict;
use warnings;

# Core
use feature qw/ say            /;
use FindBin;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Path::Tiny;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Tree::TreeBuilder;

my $exes = Cath::Gemma::Disk::Executables->new();

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );

my $tracefile_extension = '.trace';
my $basedir             = path( 'temporary_example_data' );
my $dave_tree_dir       = $basedir->child( 'tracefiles' );
my $dfx_tree_dir        = path( 'trace_files_from_2017_05_10_rerun_with_dfx_code' );
my @tracefile_dirs      = ( $dave_tree_dir, $dfx_tree_dir );

my $project_list_file   = $basedir->child( 'projects.txt' );
my $project_list_data   = $project_list_file->slurp();
my @project_list        = split( /\n/, $project_list_data );

foreach my $project ( @project_list ) {
	my $gemma_dir_set = Cath::Gemma::Disk::GemmaDirSet->new(
		scan_dir        => $basedir->child( 'output' )->child( $project ),
		profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->new(
			starting_cluster_dir => $basedir->child( 'starting_clusters' )->child( $project ),
			aln_dir              => $basedir->child( 'output'            )->child( $project ),
			prof_dir             => $basedir->child( 'output'            )->child( $project ),
		),
	);

	my $dave_tree_file = $dave_tree_dir->child( $project . $tracefile_extension );
	my $dfx_tree_file  = $dfx_tree_dir ->child( $project . $tracefile_extension );

	my $dave_tree  = Cath::Gemma::Tree::MergeList->read_from_tracefile( $dave_tree_file );
	my $dfx_tree   = Cath::Gemma::Tree::MergeList->read_from_tracefile( $dfx_tree_file  );
	my $clean_tree = Cath::Gemma::Tree::TreeBuilder->build_tree(
		$exes,
		$dfx_tree->starting_clusters(),
		$gemma_dir_set,
		path( '/dev/shm' ), # $working_dir
	);
	say ( 'DAVE  (' . $dave_tree ->geometric_mean_score() . ', ' . $dave_tree_file . ") :\n" . $dave_tree ->to_newick_string() ."\n". $dave_tree ->to_tracefile_string() );
	say ( 'DFX   (' . $dfx_tree  ->geometric_mean_score() . ', ' . $dfx_tree_file  . ") :\n" . $dfx_tree  ->to_newick_string() ."\n". $dfx_tree  ->to_tracefile_string() );
	say ( 'CLEAN (' . $clean_tree->geometric_mean_score() . ', ' .                   ") :\n" . $clean_tree->to_newick_string() ."\n". $clean_tree->to_tracefile_string() );
	say '';
	# }
}
