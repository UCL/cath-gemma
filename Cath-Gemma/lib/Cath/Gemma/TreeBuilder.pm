package Cath::Gemma::TreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars                    /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile                           /;
use Types::Path::Tiny qw/ Path                              /;
use Types::Standard   qw/ ArrayRef Bool Object Optional Str /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;

=head2 requires build_tree

=cut

requires 'build_tree';

=head2 around build_tree

=cut

around build_tree => sub {
	my $orig = shift;

	state $check = compile( Object, CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskGemmaDirSet, Path, Optional[Bool] );
	my ( $self, $exes, $starting_clusters, $gemma_dir_set, $working_dir, $use_depth_first ) = $check->( @ARG );

	# warn "In around build_tree";

	$use_depth_first //= 0;

	# Ensure all starting clusters have profiles
	foreach my $starting_cluster ( @$starting_clusters ) {
		my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
			$exes,
			[ $starting_cluster ],
			$gemma_dir_set->profile_dir_set(),
			$working_dir,
		);
	}

	# Ensure scans are in place for all-vs-all scan of starting clusters
	my $initial_scans = Cath::Gemma::Tree::MergeList->inital_scans_of_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my $result = Cath::Gemma::Tool::CompassScanner->compass_scan_to_file(
			$exes,
			[ $initial_scan->[ 0 ] ],
			$initial_scan->[ 1 ],
			$gemma_dir_set,
			$working_dir,
		);
	}

	my $scans_data = Cath::Gemma::Scan::ScansData->new_from_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my ( $query_id, $match_cluster_ids ) = @$initial_scan;
		my $filename  = $gemma_dir_set->scan_filename_of_cluster_ids( [ $query_id ], $match_cluster_ids );
		$scans_data->add_scan_data( Cath::Gemma::Scan::ScanData->read_from_file( $filename ) );
	}

	if ( scalar ( @_ ) < 6 ) {
		push @ARG, $use_depth_first;
	}
	push @ARG, $scans_data;

	$orig->( @ARG );
};

1;