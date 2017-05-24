#!/usr/bin/env perl

use strict;
use warnings;

# Core
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

# my @trace_files = (
# 	path( 'temporary_example_data/tracefiles/1.10.150.120.trace' ),
# 	path( 'temporary_example_data/tracefiles/1.10.8.40.trace' ),
# 	path( 'temporary_example_data/tracefiles/3.20.20.120.trace' ),
# 	path( 'temporary_example_data/tracefiles/3.30.390.10.trace' ),
# 	path( 'temporary_example_data/tracefiles/3.40.50.620.trace' ),
# 	path( 'temporary_example_data/tracefiles/3.40.50.970.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/1.10.150.120.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/1.10.8.40.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/3.20.20.120.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/3.30.390.10.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/3.40.50.620.trace' ),
# 	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code/3.40.50.970.trace' ),
# );
my $tracefile_extension = '.trace';
my $basedir             = path( 'temporary_example_data' );
my @tracefile_dirs      = (
	path( 'temporary_example_data/tracefiles'               ),
	path( 'trace_files_from_2017_05_10_rerun_with_dfx_code' ),
);
my $project_list_file   = $basedir->child( 'projects.txt' );
my $project_list_data   = $project_list_file->slurp();
my @project_list        = split( /\n/, $project_list_data );

foreach my $project ( @project_list ) {
	foreach my $tracefile_dir ( @tracefile_dirs ) {
		my $trace_file = $tracefile_dir->child( $project . $tracefile_extension );
		my $merge_list = Cath::Gemma::Tree::MergeList->read_from_tracefile( $trace_file );


		my $result = Cath::Gemma::Tree::TreeBuilder->build_tree(
			$exes,
			$merge_list->starting_clusters(),
			Cath::Gemma::Disk::GemmaDirSet->new(
				profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->new(
					starting_cluster_dir => $basedir->child( 'starting_clusters' )->child( $project ), # $starting_clusters_dir
					aln_dir              => $basedir->child( 'output'            )->child( $project ), # $aln_out_dir
					prof_dir             => $basedir->child( 'output'            )->child( $project ), # $prof_out_dir
				),
				scan_dir        => $basedir->child( 'output' )->child( $project ),
			),
			path( '/dev/shm' ),                                                    # $working_dir
		);
		# warn "$trace_file\t"
		# 	. $merge_list->count() . "\t" . $merge_list->geometric_mean_score() . "\t"
		# 	. $result    ->count() . "\t" . $result    ->geometric_mean_score();
		warn $result->to_tracefile_string();
	}
}
