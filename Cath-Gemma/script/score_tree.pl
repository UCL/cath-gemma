#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use feature             qw/ say            /;
use FindBin;
use Getopt::Long;
use Pod::Usage;

# Find non-core external lib directory using FindBin
use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;

# Find Gemma lib directory using FindBin (and tidy using Path::Tiny)
use lib path( "$FindBin::Bin/../lib" )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Executor::DirectExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Executor::SpawnExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder;
use Cath::Gemma::TreeBuilder::PureTreeBuilder;
use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;
use Cath::Gemma::Util;

my $help              = 0;
my $local             = 0;
my $submit_dir_name   = 'fred';
my $output_dir        = 'score_tree_output_data';
my $max_num_threads   = 6;
Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'                => \$help,
	'local'               => \$local,
	'submit-dir=s'        => \$submit_dir_name,
	'output-dir=s'        => \$output_dir,
	# 'num-local-threads=d' => \$max_num_threads,

) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

$output_dir = path( $output_dir );
if ( ! -d $output_dir ) {
	$output_dir->mkpath()
		or confess "Unable to make output directory \"$output_dir\" : $OS_ERROR";
}

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );
# /cath/people2/ucbctnl/GeMMA/v4_0_0/starting_clusters/

my $direct_executor = Cath::Gemma::Executor::DirectExecutor->new(
	max_num_threads => $max_num_threads,
);

my $executor =
	$local
		? $direct_executor
		: Cath::Gemma::Executor::SpawnExecutor->new(
			submission_dir  => path( $submit_dir_name ),
		);

my $tracefile_extension = '.trace';
my $basedir             = path( 'temporary_example_data' );
# my $dave_tree_dir       = path( '../benchmark/trace_files_from_daves_dirs'     );
# my $dfx_tree_dir        = path( '../benchmark/trace_files_from_dfx_run_201705' );
# my @tracefile_dirs      = ( $dave_tree_dir, $dfx_tree_dir );

my $project_list_file   = $basedir->child( 'projects.txt' );
my $project_list_data   = $project_list_file->slurp();
my @project_list        = grep( ! /^#/, split( /\n+/, $project_list_data ) );

foreach my $project ( @project_list ) {
	warn "Project : $project\n";

	my $gemma_dir_set = make_gemma_dir_set_of_base_dir_and_project( $basedir, $project );
	my $project_out_dir = $output_dir->child( $project );

	# foreach my $clusts_ordering ( 'simple_ordering' ) {
	# 	foreach my $compass_profile_build_type ( qw/ mk_compass_db / ) {
	# 		foreach my $tree_builder ( Cath::Gemma::TreeBuilder::PureTreeBuilder->new(),
	# 		                           ) {

	foreach my $clusts_ordering ( 'simple_ordering', 'tree_df_ordering' ) {
		foreach my $profile_build_type ( qw/ compass_wp_dummy_1st compass_wp_dummy_2nd mk_compass_db hhconsensus / ) {
			foreach my $tree_builder (
			                           Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder->new(),
			                           Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder ->new(),
			                           Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder   ->new(),
			                           Cath::Gemma::TreeBuilder::PureTreeBuilder        ->new(),
			                           Cath::Gemma::TreeBuilder::WindowedTreeBuilder    ->new(),
			                           ) {
				# my $dfx_tree_file      = $dfx_tree_dir ->child( $project . $tracefile_extension );
				# my $dfx_tree           = Cath::Gemma::Tree::MergeList->read_from_tracefile( $dfx_tree_file  );

				my $starting_clusters  = get_starting_clusters_of_starting_cluster_dir( $gemma_dir_set->starting_cluster_dir() );

				# use Data::Dumper;
				# confess Dumper( [
				# 	$gemma_dir_set->starting_cluster_dir()."",
				# 	$starting_clusters
				# ] );

				my $tree_builder_name  = $tree_builder->name();
				my $flavour            = join( '.', $clusts_ordering, $profile_build_type, $tree_builder_name );

				WARN 'About to compute flavour ' . $flavour;

				my $tree_dir_set = Cath::Gemma::Disk::TreeDirSet->new(
					gemma_dir_set => $gemma_dir_set,
					tree_dir      => $project_out_dir->child( $flavour ),
				);

				Cath::Gemma::Compute::Task::BuildTreeTask->new(
					dir_set                    => $tree_dir_set,
					starting_cluster_lists     => $starting_clusters,
					tree_builder               => $tree_builder,
					profile_build_type         => $profile_build_type,
					clusts_ordering            => $clusts_ordering,
				)->execute_task(
					$direct_executor->exes(),
					$executor
				);

				# say ( 'geom mean for    ' . $flavour . ' : ' . $tree  ->geometric_mean_score( 1e-300 ) );

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
   --output-dir        The directory in which the output should be written
   --num-local-threads The number of threads to use in a local run

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--submit_dir>

The directory in which the compute cluster submission gubbins should be written

=item B<--output_dir>

The directory in which the output should be written

TODOCUMENT

=back

=head1 DESCRIPTION

B<This program> will TODOCUMENT

=cut
