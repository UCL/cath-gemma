package Cath::Gemma::Scan::ScansDataFactory;

=head1 NAME

Cath::Gemma::Scan::ScansDataFactory - Functions to load ScansData from files

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars        /;
use v5.10;

# # Non-core (local)
use Type::Params      qw/ compile Invocant      /;
use Types::Path::Tiny qw/ Path                  /;
use Types::Standard   qw/ ArrayRef Optional Str /;

# Cath::Gemma
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Scan::ScanData;
use Cath::Gemma::Scan::ScansData;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 load_scans_data_of_starting_clusters_and_dir

TODOCUMENT

=cut

sub load_scans_data_of_starting_clusters_and_dir {
	state $check = compile( Invocant, Path, CathGemmaProfileType, ArrayRef[Str] );
	my ( $proto, $scans_dir, $profile_build_type, $starting_clusters ) = $check->( @ARG );

	my $scans_data = Cath::Gemma::Scan::ScansData->new_from_starting_clusters( $starting_clusters );

	my $initial_scans = Cath::Gemma::Tree::MergeList->inital_scans_of_starting_clusters( $starting_clusters );
	foreach my $initial_scan ( @$initial_scans ) {
		my ( $query_id, $match_cluster_ids ) = @$initial_scan;
		my $filename = scan_filename_of_dir_and_cluster_ids( $scans_dir, [ $query_id ], $match_cluster_ids, $profile_build_type );
		$scans_data->add_scan_data( Cath::Gemma::Scan::ScanData->read_from_file( $filename ) );
	}

	return $scans_data;
}

=head2 load_scans_data_of_gemma_dir_set

TODOCUMENT

=cut

sub load_scans_data_of_gemma_dir_set {
	state $check = compile( Invocant, CathGemmaDiskGemmaDirSet, CathGemmaProfileType, Optional[ArrayRef[Str]] );
	my ( $proto, $gemma_dir_set, $profile_build_type, $starting_clusters ) = $check->( @ARG );

	$starting_clusters //= $gemma_dir_set->get_starting_clusters();

	return __PACKAGE__->load_scans_data_of_starting_clusters_and_dir( $gemma_dir_set->scan_dir(), $profile_build_type, $starting_clusters );
}

=head2 load_scans_data_of_dir_and_starting_clusters_dir

TODOCUMENT

=cut

sub load_scans_data_of_dir_and_starting_clusters_dir {
	state $check = compile( Invocant, Path, CathGemmaProfileType, Path );
	my ( $proto, $scan_dir, $profile_build_type, $starting_clusters_dir ) = $check->( @ARG );

	return __PACKAGE__->load_scans_data_of_starting_clusters_and_dir(
		$scan_dir,
		$profile_build_type,
		get_starting_clusters_of_starting_cluster_dir( $starting_clusters_dir )
	);
}

=head2 load_scans_data_of_base_dir_and_project

TODOCUMENT

=cut

sub load_scans_data_of_base_dir_and_project {
	state $check = compile( Invocant, Path, Str, CathGemmaProfileType );
	my ( $proto, $base_dir, $project, $profile_build_type ) = $check->( @ARG );

	return __PACKAGE__->load_scans_data_of_gemma_dir_set(
		Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir_and_project(
			$base_dir,
			$project
		),
		$profile_build_type
	);
}

1;
