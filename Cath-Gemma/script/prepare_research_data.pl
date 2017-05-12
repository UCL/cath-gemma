#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp        qw/ confess        /;
use Data::Dumper;
use English     qw/ -no_match_vars /;
use feature     qw/ say            /;
use FindBin;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Path::Tiny;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::MergeList;

# my $trace_files_dir = path( '/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/clustering_output' );
my $trace_files_dir = path( 'temporary_example_data' );

my $trace_files_ext = '.trace';

my $visit_result = $trace_files_dir->visit(
	sub {
		my ( $tracefile_path, $state ) = @ARG;

		if ( $tracefile_path->is_dir || $tracefile_path !~ /$trace_files_ext$/ ) {
			return;
		}
		if ( "$tracefile_path" !~ /\b1\.10\.150\.120\b/ ) {
			return;
		}
		# confess ( $tracefile_path . " " );

		my $mergelist         = Cath::Gemma::MergeList->read_from_tracefile( $tracefile_path );
		my $starting_clusters = $mergelist->starting_clusters();
		# my $merge_nodes       = $mergelist->merge_nodes();
		say "Processing $tracefile_path";
		say "Starting clusters are " . join( ", ", @$starting_clusters );
		if ( ! $mergelist->is_empty() ) {
			my $num_merges_less_one = $mergelist->count() - 1;
			foreach my $merge_ctr ( 0 .. $num_merges_less_one ) {
				my $merge = $mergelist->merge_of_index( $merge_ctr );
				say join( " ", @{ $merge->starting_nodes_in_depth_first_traversal_order() } );
				say $merge->standard_order_id();
				say join( " ", @{ $merge->starting_nodes_in_standard_order             () } );
				say $merge->depth_first_traversal_id();
			}
		}
		# confess "STOP ";
	},
);
