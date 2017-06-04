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

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Compute::ProfileBuildTask;
use Cath::Gemma::Compute::WorkBatcher;
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Tree::MergeList;

my $help = 0;
my $submission_dir_name = 'fred';
Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'         => \$help,
	'submit_dir=s' => \$submission_dir_name,
) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

my $exes = Cath::Gemma::Disk::Executables->new();

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );

my $trace_files_ext            = '.trace';

my $aln_out_basedir            = path( 'temporary_example_data/output'            );
my $prof_out_basedir           = path( 'temporary_example_data/output'            );
my $projects_list_file         = path( 'temporary_example_data/projects.txt' );
my $scan_dir                   = path( 'temporary_example_data/output'            );
my $starting_clusters_base_dir = path( 'temporary_example_data/starting_clusters' );
my $trace_files_dir            = path( 'temporary_example_data/tracefiles'        );
my $working_dir                = path( '/dev/shm'                                 );

my $projects_list_data = $projects_list_file->slurp();
my @projects = split( /\n+/, $projects_list_data );

my $executor = Cath::Gemma::Executor::LocalExecutor->new();
# my $executor = Cath::Gemma::Executor::HpcExecutor->new();

foreach my $project ( @projects ) {
	my $tracefile_path = $trace_files_dir->child( $project . $trace_files_ext );
	if ( ! -s $tracefile_path ) {
		confess "No such tracefile \"$tracefile_path\" for project $project";
	}

	my $starting_clusters_dir = $starting_clusters_base_dir->child( $project )->realpath();
	if ( ! -d $starting_clusters_dir ) {
		confess "No such stating clusters dir \"$starting_clusters_dir\" for project $project"
	}
	my $aln_out_dir  = $aln_out_basedir ->child( $project )->realpath();
	my $prof_out_dir = $prof_out_basedir->child( $project )->realpath();
	foreach my $outdir ( $aln_out_dir, $prof_out_dir ) {
		if ( ! -d $outdir ) {
			$outdir->mkpath()
				or confess "Unable to make output directory \"$outdir\" : $OS_ERROR";
		}
	}

	my $gemma_dir_set = Cath::Gemma::Disk::ProfileDirSet->new(
		profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->new(
			starting_cluster_dir => $starting_clusters_dir,
			aln_dir              => $aln_out_dir,
			prof_dir             => $prof_out_dir,
		),
		scan_dir        => $scan_dir,
	);

	my $mergelist = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tracefile_path );
	if ( $mergelist->is_empty() ) {
		WARN "Cannot do any further processing for an empty merge list (read from file \"$tracefile_path\")";
		return;
	}

	$executor->execute(

		# Build alignments and profiles for...
		[
			# ...all starting_clusters
			Cath::Gemma::Compute::ProfileBuildTask->new(
				starting_cluster_lists => $mergelist    ->starting_cluster_lists(),
				dir_set                => $gemma_dir_set->profile_dir_set       (),
			)->remove_already_present(),

			# ...all merge nodes (use_depth_first:0)
			Cath::Gemma::Compute::ProfileBuildTask->new(
				starting_cluster_lists => $mergelist    ->merge_cluster_lists( 0 ),
				dir_set                => $gemma_dir_set->profile_dir_set    (   ),
			)->remove_already_present(),

			# ...all merge nodes (use_depth_first:1)
			Cath::Gemma::Compute::ProfileBuildTask->new(
				starting_cluster_lists => $mergelist    ->merge_cluster_lists( 1 ),
				dir_set                => $gemma_dir_set->profile_dir_set    (   ),
			)->remove_already_present(),
		],

		# Perform scans for...
		[
			# ...all initial nodes (ie starting cluster vs other starting clusters)
			Cath::Gemma::Compute::ProfileScanTask->new(
				$mergelist->initial_scan_lists( 0 ),
				dir_set => $gemma_dir_set,
			),

			# ...all merge nodes (use_depth_first:0)
			Cath::Gemma::Compute::ProfileScanTask->new(
				$mergelist->later_scan_lists( 0 ),
				dir_set => $gemma_dir_set,
			),

			# ...all merge nodes (use_depth_first:1)
			Cath::Gemma::Compute::ProfileScanTask->new(
				$mergelist->later_scan_lists( 1 ),
				dir_set => $gemma_dir_set,
			),

		]
	);

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
