package Cath::Gemma::Scan::ScansDataFactory;

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars   /;
use v5.10;

# # Non-core (local)
use Type::Params      qw/ compile Invocant /;
use Types::Path::Tiny qw/ Path             /;
use Types::Standard   qw/ ArrayRef Str     /;

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Scan::ScanData;
use Cath::Gemma::Scan::ScansData;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 load_scans_data_of_starting_clusters_and_dir

TODOCUMENT

=cut

sub load_scans_data_of_starting_clusters_and_dir {
	state $check = compile( Invocant, ArrayRef[Str], Path, CathGemmaCompassProfileType );
	my ( $proto, $starting_clusters, $starting_clusters_dir, $compass_profile_build_type ) = $check->( @ARG );

	my $scans_data = Cath::Gemma::Scan::ScansData->new_from_starting_clusters( $starting_clusters );

	my $initial_scans = Cath::Gemma::Tree::MergeList->inital_scans_of_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my ( $query_id, $match_cluster_ids ) = @$initial_scan;
		my $filename = scan_filename_of_dir_and_cluster_ids( $starting_clusters_dir, [ $query_id ], $match_cluster_ids, $compass_profile_build_type );
		$scans_data->add_scan_data( Cath::Gemma::Scan::ScanData->read_from_file( $filename ) );
	}

	return $scans_data;
}

=head2 load_scans_data_of_starting_clusters_and_gemma_dir_set

TODOCUMENT

=cut

sub load_scans_data_of_starting_clusters_and_gemma_dir_set {
	state $check = compile( Invocant, ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType );
	my ( $proto, $starting_clusters, $gemma_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	return __PACKAGE__->load_scans_data_of_starting_clusters_and_dir( $starting_clusters, $gemma_dir_set->scan_dir(), $compass_profile_build_type );
}

1;
