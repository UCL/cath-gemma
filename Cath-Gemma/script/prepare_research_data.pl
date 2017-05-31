#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp    qw/ confess        /;
use English qw/ -no_match_vars /;
use feature qw/ say            /;
use FindBin;
use Getopt::Long;
use Pod::Usage;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
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
my $submission_dir_name;
Getopt::Long::Configure( 'bundling' );
GetOptions(
	'help'         => \$help,
	'submit_dir=s' => \$submission_dir_name,
) or pod2usage( 2 );
if ( $help ) {
	pod2usage( 1 );
}

# my $submission_dir_name = 'fred';

use Data::Dumper;
confess Dumper( $submission_dir_name );


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

my $work_batcher = Cath::Gemma::Compute::WorkBatcher->new();

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

	my $mergelist = Cath::Gemma::Tree::MergeList->read_from_tracefile( $tracefile_path );

	# Print the starting clusters
	# warn join( " ", @{ $mergelist->starting_clusters() } );
	# say join( " ", @{ $mergelist->starting_clusters() } );

	$work_batcher->add_profile_build_work(
		Cath::Gemma::Compute::ProfileBuildTask->new(
			starting_cluster_lists => $mergelist->starting_cluster_lists(),
			dir_set                => Cath::Gemma::Disk::ProfileDirSet->new(
				starting_cluster_dir => $starting_clusters_dir,
				aln_dir              => $aln_out_dir,
				prof_dir             => $prof_out_dir,
			),
		)->remove_already_present()
	);

	# # Build alignments and profiles for all starting_clusters
	# foreach my $starting_cluster ( @{ $mergelist->starting_clusters() } ) {
	# 	my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
	# 		$exes,
	# 		[ $starting_cluster ],
	# 		$starting_clusters_dir,
	# 		$aln_out_dir,
	# 		$prof_out_dir,
	# 		$working_dir,
	# 	);
	# 	say join( ', ', map { $ARG . ':' . $build_aln_and_prof_result->{ $ARG } } keys( %$build_aln_and_prof_result ) );
	# }

	# # Build alignments and profiles for all merge nodes
	# if ( ! $mergelist->is_empty() ) {
	# 	foreach my $merge_ctr ( 0 .. ( $mergelist->count() - 1 ) ) {
	# 		my $merge = $mergelist->merge_of_index( $merge_ctr );

	# 		foreach my $use_depth_first ( 0, 1 ) {
	# 			my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
	# 				$exes,
	# 				$merge->starting_nodes( $use_depth_first ),
	# 				$starting_clusters_dir,
	# 				$aln_out_dir,
	# 				$prof_out_dir,
	# 				$working_dir,
	# 			);
	# 			say join( ', ', map { $ARG . ':' . $build_aln_and_prof_result->{ $ARG } } keys( %$build_aln_and_prof_result ) );
	# 		}
	# 	}
	# }

	# # say '';

	# # Perform all initial (ie starting cluster vs other starting clusters) scans
	# foreach my $scan ( @{$mergelist->initial_scans()  } ) {
	# 	my $result = Cath::Gemma::Tool::CompassScanner->compass_scan_to_file(
	# 		$exes,
	# 		$prof_out_dir,
	# 		[ $scan->[ 0 ] ],
	# 		$scan->[ 1 ],
	# 		$scan_dir,
	# 		$working_dir,
	# 	);
	# 	say join( ', ', map { $ARG . ':' . $result->{ $ARG } } keys( %$result ) );
	# 	# say join( "\n", map { join( "\t", @$ARG ); } @{ $result->{ data } } );
	# }

	# # say '';

	# # Perform all merge node scans
	# foreach my $use_depth_first ( 0, 1 ) {
	# 	foreach my $scan ( @{ $mergelist->later_scans( $use_depth_first ) } ) {
	# 		my $result = Cath::Gemma::Tool::CompassScanner->compass_scan_to_file(
	# 			$exes,
	# 			$prof_out_dir,
	# 			[ $scan->[ 0 ] ],
	# 			$scan->[ 1 ],
	# 			$scan_dir,
	# 			$working_dir,
	# 		);
	# 		say join( ', ', map { $ARG . ':' . $result->{ $ARG } } keys( %$result ) );
	# 		# say join( "\n", map { join( "\t", @$ARG ); } @{ $result->{ data } } );
	# 	}
	# }
}

$work_batcher->submit_to_compute_cluster( path( 'fred' )->realpath() );

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
