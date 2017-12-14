#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp                qw/ confess                 /;
use English             qw/ -no_match_vars          /;
use feature             qw/ say                     /;
use FindBin;
use Getopt::Long;
use Pod::Usage;
use v5.10;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                   /;
use Path::Tiny;
use Type::Params        qw/ compile                 /;
use Types::Standard     qw/ ArrayRef Int Object Str /; # ***** TEMPORARY *****

use lib path( "$FindBin::Bin/../lib" )->realpath()->stringify();

# Cath
use Cath::Gemma::Compute::Task::BuildTreeTask;
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Compute::WorkBatch;
use Cath::Gemma::Compute::WorkBatcher;
use Cath::Gemma::Compute::WorkBatchList;
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Disk::TreeDirSet;
use Cath::Gemma::Executor::HpcExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Executor::LocalExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder;
use Cath::Gemma::TreeBuilder::PureTreeBuilder;
use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;
use Cath::Gemma::Types  qw/
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskTreeDirSet
	CathGemmaTreeMergeList
/;
use Cath::Gemma::Util;

use Type::Tiny;
$Error::TypeTiny::StackTrace = 1;

my $trace_files_ext            = '.trace';

# my @COMPASS_PROFILE_TYPES = ( qw/ compass_wp_dummy_1st compass_wp_dummy_2nd mk_compass_db / );
# my @NODE_ORDERINGS        = ( qw/ tree_df_ordering simple_ordering                        / );
# my @TREE_BUILDERS         = (
# 	Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder->new(),
# 	Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder ->new(),
# 	Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder   ->new(),
# 	Cath::Gemma::TreeBuilder::PureTreeBuilder        ->new(),
# 	Cath::Gemma::TreeBuilder::WindowedTreeBuilder    ->new(),
# );

my @COMPASS_PROFILE_TYPES = ( qw/                                           mk_compass_db / );
my @NODE_ORDERINGS        = ( qw/                  simple_ordering                        / );
my @TREE_BUILDERS         = ( Cath::Gemma::TreeBuilder::WindowedTreeBuilder->new()          );

{

my $help            = 0;
my $local           = 0;
my $max_num_threads = 6;

# my $starting_clusters_rootdir;
my $projects_list_file;

my $submission_dir_pattern = 'submit_dir.XXXXXXXXXXX';

my $output_rootdir;
# my $output_aln_rootdir;
# my $output_prof_rootdir;
# my $output_scan_rootdir;
# my $trace_files_rootdir;

Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'                        => \$help,
	'local'                       => \$local,
	'submit-dir-pattern=s'        => \$submission_dir_pattern,

	# 'starting-cluster-root-dir=s' => \$starting_clusters_rootdir,
	'projects-list-file=s'        => \$projects_list_file,

	'output-root-dir=s'           => \$output_rootdir,
	# 'submit-dir=s'                => \$submission_dir_name,
	# 'submit-dir=s'                => \$submission_dir_name,
) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

# if ( ! defined( $starting_clusters_rootdir ) ) {
# 	confess "Must specify a starting-cluster-root-dir";
# }
if ( ! defined( $projects_list_file ) ) {
	confess "Must specify a projects-list-file";
}
if ( ! defined( $output_rootdir ) ) {
	confess "Must specify a output-root-dir";
}

$output_rootdir              = path( $output_rootdir             )->realpath();
$projects_list_file          = path( $projects_list_file         )->realpath();
# $starting_clusters_rootdir   = path( $starting_clusters_rootdir  )->realpath();
$submission_dir_pattern      = path( $submission_dir_pattern     )->realpath();
# $output_aln_rootdir        //= $output_rootdir->child( 'alignments'      );
# $output_prof_rootdir       //= $output_rootdir->child( 'profiles'        );
# $output_scan_rootdir       //= $output_rootdir->child( 'scans'           );


##########################################################################################

my $projects_list_data = $projects_list_file->slurp()
	or confess "Was unable to read any projects from project list file $projects_list_file";
my @projects = grep( ! /^#/, split( /\n+/, $projects_list_data ) );

my $executor =
	$local
		? Cath::Gemma::Executor::LocalExecutor->new(
			max_num_threads => $max_num_threads,
		)
		: Cath::Gemma::Executor::HpcExecutor->new(
			submission_dir  => Path::Tiny->tempdir(
				TEMPLATE => $submission_dir_pattern->basename(),
				DIR      => $submission_dir_pattern->parent(),
				CLEANUP  => 0,
			),
			# hpc_mode => 'hpc_sge',
		);

if ( 0 ) {
	my $work_batch_list = Cath::Gemma::Compute::WorkBatchList->new(
		batches => [ map {
			my $project = $ARG;

			@{ work_batches_for_mergelist(
				Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir_and_project(
					$output_rootdir,
					$project
				)
			) };
		} @projects ],
	);

	if ( $work_batch_list->num_batches() == 0 ) {
		INFO "No build/scan work to do";
	}
	else {
		my $rebatched = Cath::Gemma::Compute::WorkBatcher->new()->rebatch( $work_batch_list );
		INFO "".( $rebatched->num_batches() . " build/scan batches to process" );
		$executor->execute( $work_batch_list, 'permit_async_launch' );
	}
}

if ( 1 ) {
	my $treebuild_batch_list = Cath::Gemma::Compute::WorkBatchList->new(
		batches => [ map {
			my $project = $ARG;

			@{ treebuild_batches(
				Cath::Gemma::Disk::TreeDirSet->make_tree_dir_set_of_base_dir_and_project(
					$output_rootdir,
					$project
				)
			) };
		} @projects ],
	);

	if ( $treebuild_batch_list->num_batches() == 0 ) {
		INFO "No treebuild work to do";
	}
	else {
		# INFO "Rebatching " . ( $treebuild_batch_list->num_batches() ) . " batches";
		# my $rebatched = Cath::Gemma::Compute::WorkBatcher->new()->rebatch( $treebuild_batch_list );
		# INFO "".( $rebatched->num_batches() . " treebuild batches to process" );
		INFO "".( $treebuild_batch_list->num_batches() . " build/scan batches to process" );
		$executor->execute( $treebuild_batch_list, 'permit_async_launch' );
	}
}

}


sub work_batches_for_mergelist {
	state $check = compile( CathGemmaDiskGemmaDirSet );
	my ( $gemma_dir_set ) = $check->( @ARG );

	my $starting_clusters = $gemma_dir_set->get_starting_clusters();

	return [
		map {
			my $compass_profile_build_type = $ARG;

			my $work_batch = Cath::Gemma::Compute::WorkBatch->new(
				# Build alignments and profiles for...
				profile_tasks => Cath::Gemma::Compute::Task::ProfileBuildTask->remove_duplicate_build_tasks( [
					# ...all starting_clusters
					Cath::Gemma::Compute::Task::ProfileBuildTask->new(
						starting_cluster_lists     => [ map { [ $ARG ]; } @$starting_clusters ],
						dir_set                    => $gemma_dir_set->profile_dir_set       (),
						compass_profile_build_type => $compass_profile_build_type,
					)->remove_already_present(),

					# # ...all merge nodes from the source trace file (simple_ordering)
					# Cath::Gemma::Compute::Task::ProfileBuildTask->new(
					# 	starting_cluster_lists     => $mergelist    ->merge_cluster_lists( 'simple_ordering'  ),
					# 	dir_set                    => $gemma_dir_set->profile_dir_set    (                    ),
					# 	compass_profile_build_type => $compass_profile_build_type,
					# )->remove_already_present(),

					# # ...all merge nodes from the source trace file (tree_df_ordering)
					# Cath::Gemma::Compute::Task::ProfileBuildTask->new(
					# 	starting_cluster_lists     => $mergelist    ->merge_cluster_lists( 'tree_df_ordering' ),
					# 	dir_set                    => $gemma_dir_set->profile_dir_set    (                    ),
					# 	compass_profile_build_type => $compass_profile_build_type,
					# )->remove_already_present(),
				] ),

				# Perform scans for...
				scan_tasks => Cath::Gemma::Compute::Task::ProfileScanTask->remove_duplicate_scan_tasks( [
					# ...all initial nodes (ie starting cluster vs other starting clusters)
					Cath::Gemma::Compute::Task::ProfileScanTask->new(
						starting_cluster_list_pairs => Cath::Gemma::Tree::MergeList->inital_scan_lists_of_starting_clusters(
							$starting_clusters
						),
						dir_set                     => $gemma_dir_set,
						compass_profile_build_type  => $compass_profile_build_type,
					)->remove_already_present(),

					# # ...all merge nodes from the source trace file (simple_ordering)
					# Cath::Gemma::Compute::Task::ProfileScanTask->new(
					# 	starting_cluster_list_pairs => $mergelist->later_scan_lists( 'simple_ordering'  ),
					# 	dir_set                     => $gemma_dir_set,
					# 	compass_profile_build_type  => $compass_profile_build_type,
					# )->remove_already_present(),

					# # ...all merge nodes from the source trace file (tree_df_ordering)
					# Cath::Gemma::Compute::Task::ProfileScanTask->new(
					# 	starting_cluster_list_pairs => $mergelist->later_scan_lists( 'tree_df_ordering' ),
					# 	dir_set                     => $gemma_dir_set,
					# 	compass_profile_build_type  => $compass_profile_build_type,
					# )->remove_already_present(),
				] ),
			)->remove_empty_tasks();
			$work_batch->is_empty() ? (             )
			                        : ( $work_batch );
		} @COMPASS_PROFILE_TYPES
	];
}


sub treebuild_batches {
	state $check = compile( CathGemmaDiskTreeDirSet );
	my ( $tree_dir_set ) = $check->( @ARG );

	return [
		map {
			my $tree_builder = $ARG;
			map {
				my $compass_profile_build_type = $ARG;
				map {
					my $clusts_ordering = $ARG;

					Cath::Gemma::Compute::WorkBatch->new(
						treebuild_tasks => [
							Cath::Gemma::Compute::Task::BuildTreeTask->new(
								clusts_ordering            => $clusts_ordering,
								compass_profile_build_type => $compass_profile_build_type,
								dir_set                    => $tree_dir_set,
								starting_cluster_lists     => [ $tree_dir_set->get_starting_clusters() ],
								tree_builder               => $tree_builder,
							)
						]
					);

				} @NODE_ORDERINGS;
			} @COMPASS_PROFILE_TYPES
		} @TREE_BUILDERS
	];
}

__END__

=head1 NAME

prepare_research_data.pl - TODOCUMENT

=head1 SYNOPSIS

prepare_research_data.pl [options]

 Options:
   --help            brief help message

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=back

=head1 DESCRIPTION

B<This program> will TODOCUMENT

=cut
