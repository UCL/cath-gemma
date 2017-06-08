#!/usr/bin/env perl

use strict;
use warnings;

# Core
use feature qw/ say            /;
use English qw/ -no_match_vars /;
use FindBin;
use Getopt::Long;
use Pod::Usage;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Path::Tiny;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Executor::HpcExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Executor::LocalExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::TreeBuilder::PureTreeBuilder;
use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;

my $help              = 0;
my $local             = 0;
my $submit_dir_name   = 'fred';
my $max_num_threads = 6;
Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'                => \$help,
	'local'               => \$local,
	'submit-dir=s'        => \$submit_dir_name,
	# 'num-local-threads=d' => \$max_num_threads,

) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );
# /cath/people2/ucbctnl/GeMMA/v4_0_0/starting_clusters/

my $executor =
	$local
		? Cath::Gemma::Executor::LocalExecutor->new(
			max_num_threads => $max_num_threads,
		)
		: Cath::Gemma::Executor::HpcExecutor->new(
			submission_dir  => path( $submit_dir_name ),
		);

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
	foreach my $use_depth_first ( 0, 1 ) {
		foreach my $compass_profile_build_type ( qw/ compass_wp_dummy_1st compass_wp_dummy_2nd mk_compass_db / ) {
			foreach my $tree_builder ( Cath::Gemma::TreeBuilder::PureTreeBuilder    ->new(),
			                           Cath::Gemma::TreeBuilder::WindowedTreeBuilder->new(),
			                           ) {
				my $dfx_tree_file = $dfx_tree_dir ->child( $project . $tracefile_extension );
				my $dfx_tree      = Cath::Gemma::Tree::MergeList->read_from_tracefile( $dfx_tree_file  );

				my $descriptive_string = '.' . $tree_builder->name() . '.df' . $use_depth_first . '.' . $compass_profile_build_type;
				my $tree = $tree_builder->build_tree(
					$executor,
					$dfx_tree->starting_clusters(),
					$gemma_dir_set,
					$compass_profile_build_type,
					$use_depth_first,
				);
				$tree  ->write_to_newick_file( $project . $descriptive_string . '.newick'      );
				say ( 'WINDOW  (' . $descriptive_string . $tree  ->geometric_mean_score() . ") :\n" );

			}
		}
	}
}

=head1 NAME

score_tree.pl - TODOCUMENT

=head1 SYNOPSIS

score_tree.pl [options]

 Options:
   --help              Brief help message
   --local             Perform all computation locally
   --submit-dir        The directory in which the compute cluster submission gubbins should be written
   --num-local-threads The number of threads to use in a local run

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--submit_dir>

The directory in which the compute cluster submission gubbins should be written

TODOCUMENT

=back

=head1 DESCRIPTION

B<This program> will TODOCUMENT

=cut
