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

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Compute::WorkBatch;
use Cath::Gemma::Compute::WorkBatcher;
use Cath::Gemma::Compute::WorkBatchList;
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Executor::HpcExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Executor::LocalExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Types  qw/
	CathGemmaDiskGemmaDirSet
	CathGemmaTreeMergeList
/;

use Type::Tiny;
$Error::TypeTiny::StackTrace = 1;

my $trace_files_ext            = '.trace';

{

my $help            = 0;
my $local           = 0;
my $max_num_threads = 6;

my $starting_clusters_rootdir ;
my $projects_list_file;

my $submission_dir_pattern = 'submit_dir.XXXXXXXXXXX';

my $output_rootdir;
my $output_aln_rootdir;
my $output_prof_rootdir;
my $output_scan_rootdir;
# my $trace_files_rootdir;

my $src_trace_files_rootdir;

Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'                        => \$help,
	'local'                       => \$local,
	'submit-dir-pattern=s'        => \$submission_dir_pattern,

	'starting-cluster-root-dir=s' => \$starting_clusters_rootdir,
	'projects-list-file=s'        => \$projects_list_file,

	'output-root-dir=s'           => \$output_rootdir,
	# 'submit-dir=s'                => \$submission_dir_name,
	# 'submit-dir=s'                => \$submission_dir_name,
) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

if ( ! defined( $starting_clusters_rootdir ) ) {
	confess "Must specify a starting-cluster-root-dir";
}
if ( ! defined( $projects_list_file ) ) {
	confess "Must specify a projects-list-file";
}
if ( ! defined( $output_rootdir ) ) {
	confess "Must specify a output-root-dir";
}

$output_rootdir              = path( $output_rootdir             )->realpath();
$projects_list_file          = path( $projects_list_file         )->realpath();
$starting_clusters_rootdir   = path( $starting_clusters_rootdir  )->realpath();
$submission_dir_pattern      = path( $submission_dir_pattern     )->realpath();
$output_aln_rootdir        //= $output_rootdir->child( 'alignments'      );
$output_prof_rootdir       //= $output_rootdir->child( 'profiles'        );
$output_scan_rootdir       //= $output_rootdir->child( 'scans'           );
$src_trace_files_rootdir   //= $output_rootdir->child( 'dave_tracefiles' );


##########################################################################################

my $projects_list_data = $projects_list_file->slurp()
	or confess "Was unable to read any projects from project list file $projects_list_file";
my @projects = grep( ! /^#/, split( /\n+/, $projects_list_data ) );

my $work_batch_list = Cath::Gemma::Compute::WorkBatchList->new(
	batches => [ map {
		my $project = $ARG;

		# Grab the source merge list
		my $tracefile_path = $src_trace_files_rootdir->child( $project . $trace_files_ext );
		my $mergelist = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tracefile_path );
		if ( $mergelist->is_empty() ) {
			WARN "Cannot do any further processing for an empty merge list (read from file \"$tracefile_path\")";
			return;
		}

		# Build a GemmaDirSet for the project
		my $gemma_dir_set = Cath::Gemma::Disk::GemmaDirSet->new(
			profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->new(
				starting_cluster_dir => $starting_clusters_rootdir->child( $project ),
				aln_dir              => $output_aln_rootdir       ->child( $project ),
				prof_dir             => $output_prof_rootdir      ->child( $project ),
			),
			scan_dir => $output_scan_rootdir->child( $project ),
		);

		@{ work_batches_for_mergelist( $gemma_dir_set, $mergelist ) };
	} @projects ],
);


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

$executor->execute( $work_batch_list );

}

sub work_batches_for_mergelist {
	state $check = compile( CathGemmaDiskGemmaDirSet, CathGemmaTreeMergeList );
	my ( $gemma_dir_set, $mergelist ) = $check->( @ARG );

	return [
		map {
			my $compass_profile_build_type = $ARG;

			Cath::Gemma::Compute::WorkBatch->new(
				# Build alignments and profiles for...
				profile_tasks => Cath::Gemma::Compute::Task::ProfileBuildTask->remove_duplicate_build_tasks( [
					# ...all starting_clusters
					Cath::Gemma::Compute::Task::ProfileBuildTask->new(
						starting_cluster_lists     => $mergelist    ->starting_cluster_lists(),
						dir_set                    => $gemma_dir_set->profile_dir_set       (),
						compass_profile_build_type => $compass_profile_build_type,
					)->remove_already_present(),

					# ...all merge nodes from the source trace file (simple_ordering)
					Cath::Gemma::Compute::Task::ProfileBuildTask->new(
						starting_cluster_lists     => $mergelist    ->merge_cluster_lists( 'simple_ordering'  ),
						dir_set                    => $gemma_dir_set->profile_dir_set    (                    ),
						compass_profile_build_type => $compass_profile_build_type,
					)->remove_already_present(),

					# ...all merge nodes from the source trace file (tree_df_ordering)
					Cath::Gemma::Compute::Task::ProfileBuildTask->new(
						starting_cluster_lists     => $mergelist    ->merge_cluster_lists( 'tree_df_ordering' ),
						dir_set                    => $gemma_dir_set->profile_dir_set    (                    ),
						compass_profile_build_type => $compass_profile_build_type,
					)->remove_already_present(),
				] ),

				# Perform scans for...
				scan_tasks => Cath::Gemma::Compute::Task::ProfileScanTask->remove_duplicate_scan_tasks( [
					# ...all initial nodes (ie starting cluster vs other starting clusters)
					Cath::Gemma::Compute::Task::ProfileScanTask->new(
						starting_cluster_list_pairs => $mergelist->initial_scan_lists(),
						dir_set                     => $gemma_dir_set,
						compass_profile_build_type  => $compass_profile_build_type,
					)->remove_already_present(),

					# ...all merge nodes from the source trace file (simple_ordering)
					Cath::Gemma::Compute::Task::ProfileScanTask->new(
						starting_cluster_list_pairs => $mergelist->later_scan_lists( 'simple_ordering'  ),
						dir_set                     => $gemma_dir_set,
						compass_profile_build_type  => $compass_profile_build_type,
					)->remove_already_present(),

					# ...all merge nodes from the source trace file (tree_df_ordering)
					Cath::Gemma::Compute::Task::ProfileScanTask->new(
						starting_cluster_list_pairs => $mergelist->later_scan_lists( 'tree_df_ordering' ),
						dir_set                     => $gemma_dir_set,
						compass_profile_build_type  => $compass_profile_build_type,
					)->remove_already_present(),
				] ),
			);
		}
		( qw/ compass_wp_dummy_1st compass_wp_dummy_2nd mk_compass_db / )
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
