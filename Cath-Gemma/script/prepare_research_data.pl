#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp    qw/ confess        /;
use English qw/ -no_match_vars /;
use feature qw/ say            /;
use FindBin;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Path::Tiny;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Aligner;
use Cath::Gemma::CompassProfileBuilder;
use Cath::Gemma::CompassScanner;
use Cath::Gemma::MergeList;
use Cath::Gemma::Executables;

my $exes = Cath::Gemma::Executables->new();

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );
my $trace_files_dir = path( 'temporary_example_data' );

my $trace_files_ext = '.trace';

my $starting_clusters_dir = path( 'temporary_example_data/starting_clusters' );
my $aln_dir               = path( 'temporary_example_data/output'            );
my $prof_dir              = path( 'temporary_example_data/output'            );
my $scan_dir              = path( 'temporary_example_data/output'            );
my $working_dir           = path( '/dev/shm'                                 );

my $visit_result = $trace_files_dir->visit(
	sub {
		my ( $tracefile_path, $state ) = @ARG;

		if ( $tracefile_path->is_dir || $tracefile_path !~ /$trace_files_ext$/ ) {
			return;
		}
		if ( "$tracefile_path" !~ /\b1\.10\.150\.120\b/ ) {
			return;
		}

		my $mergelist         = Cath::Gemma::MergeList->read_from_tracefile( $tracefile_path );

		# Print the starting clusters
		say join( " ", @{ $mergelist->starting_clusters() } );

		# Build alignments and profiles for all starting_clusters
		foreach my $starting_cluster (@{ $mergelist->starting_clusters() } ) {
			my $build_aln_and_prof_result = Cath::Gemma::CompassProfileBuilder->build_alignment_and_compass_profile(
				$exes,
				[ $starting_cluster ],
				$starting_clusters_dir,
				$aln_dir,
				$prof_dir,
				$working_dir,
			);
			say join( ', ', map { $ARG . ':' . $build_aln_and_prof_result->{ $ARG } } keys( %$build_aln_and_prof_result ) );
		}

		# Build alignments and profiles for all merge nodes
		if ( ! $mergelist->is_empty() ) {
			foreach my $merge_ctr ( 0 .. ( $mergelist->count() - 1 ) ) {
				my $merge = $mergelist->merge_of_index( $merge_ctr );

				foreach my $use_depth_first ( 0, 1 ) {
					my $build_aln_and_prof_result = Cath::Gemma::CompassProfileBuilder->build_alignment_and_compass_profile(
						$exes,
						$merge->starting_nodes( $use_depth_first ),
						$starting_clusters_dir,
						$aln_dir,
						$prof_dir,
						$working_dir,
					);
					say join( ', ', map { $ARG . ':' . $build_aln_and_prof_result->{ $ARG } } keys( %$build_aln_and_prof_result ) );
				}
			}
		}

		# say '';

		# Perform all initial (ie starting cluster vs other starting clusters) scans
		foreach my $scan ( @{$mergelist->initial_scans()  } ) {
			my $result = Cath::Gemma::CompassScanner->compass_scan_to_file(
				$exes,
				$prof_dir,
				[ $scan->[ 0 ] ],
				$scan->[ 1 ],
				$scan_dir,
				$working_dir,
			);
			say join( ', ', map { $ARG . ':' . $result->{ $ARG } } keys( %$result ) );
			# say join( "\n", map { join( "\t", @$ARG ); } @{ $result->{ data } } );
		}

		# say '';

		# Perform all merge node scans
		foreach my $use_depth_first ( 0, 1 ) {
			foreach my $scan ( @{ $mergelist->later_scans( $use_depth_first ) } ) {
				my $result = Cath::Gemma::CompassScanner->compass_scan_to_file(
					$exes,
					$prof_dir,
					[ $scan->[ 0 ] ],
					$scan->[ 1 ],
					$scan_dir,
					$working_dir,
				);
				say join( ', ', map { $ARG . ':' . $result->{ $ARG } } keys( %$result ) );
				# say join( "\n", map { join( "\t", @$ARG ); } @{ $result->{ data } } );
			}
		}
	},
);
