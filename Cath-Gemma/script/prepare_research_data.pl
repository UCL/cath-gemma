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

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );
my $trace_files_dir = path( 'temporary_example_data' );

my $trace_files_ext = '.trace';

my $starting_clusters_dir = path( 'temporary_example_data/starting_clusters' );
my $aln_dir               = path( 'temporary_example_data/output'            );
my $prof_dir              = path( 'temporary_example_data/output'            );
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

		warn join( " ", @{ $mergelist->starting_clusters() } );

		warn "\n";

		my $initial_scans = $mergelist->initial_scans();
		foreach my $initial_scan ( @$initial_scans ) {
			warn $initial_scan->[ 0 ] . "\tvs\t" . join( "\t", @{ $initial_scan->[ 1 ] } ) . "\n";
		}

		warn "\n";

		my $later_scans = $mergelist->later_scans( 0 );
		foreach my $later_scan ( @$later_scans ) {
			warn $later_scan->[ 0 ] . "\tvs\t" . join( "\t", @{ $later_scan->[ 1 ] } ) . "\n";
		}

		warn "\n";

		my $starting_clusters = $mergelist->starting_clusters();

		foreach my $starting_cluster (@$starting_clusters) {
			my $align_result = Cath::Gemma::Aligner->make_alignment_file(
				[ $starting_cluster ],
				$starting_clusters_dir,
				$aln_dir,
				$working_dir,
			);
			my $prof_result = Cath::Gemma::CompassProfileBuilder->build_compass_profile(
				$align_result->{ out_filename },
				$prof_dir,
				$working_dir,
			);
		}

		# my $merge_nodes       = $mergelist->merge_nodes();
		# say "Processing $tracefile_path";
		# say "Starting clusters are " . join( ", ", @$starting_clusters );
		if ( ! $mergelist->is_empty() ) {
			my $num_merges_less_one = $mergelist->count() - 1;
			foreach my $merge_ctr ( 0 .. $num_merges_less_one ) {
				my $merge = $mergelist->merge_of_index( $merge_ctr );
				say join( " ", @{ $merge->starting_nodes( 1 ) } );
				say $merge->id( 1 );
				say join( " ", @{ $merge->starting_nodes( 0 ) } );
				say $merge->id( 0 );
				my $align_result = Cath::Gemma::Aligner->make_alignment_file(
					$merge->starting_nodes( 1 ),
					$starting_clusters_dir,
					$aln_dir,
					$working_dir,
				);
				my $prof_result = Cath::Gemma::CompassProfileBuilder->build_compass_profile(
					$align_result->{ out_filename },
					$prof_dir,
					$working_dir,
				);
			}
		}

		my $result = Cath::Gemma::CompassScanner->compass_scan(
			$prof_dir,
			[ qw/ 1266 354 2798 2358 1041 355 1267 b27aa16141d9de58e50516ab501d3ed7 / ],
			[ qw/ 840  869 925  781  975  722 365  84ae11efeba97b2d50e0d542abcb9a37 / ],
			$working_dir,
		);
		warn join( "\n", map { join( "\t", @$ARG ); } @$result )."\n";
	},
);
