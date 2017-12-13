package Cath::Gemma::Disk::GemmaDirSet;

use strict;
use warnings;

# Core
use Carp               qw/ confess                    /;
use English            qw/ -no_match_vars             /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params       qw/ compile Invocant           /;
use Types::Path::Tiny  qw/ Path                       /;
use Types::Standard    qw/ ArrayRef Object Str        /;

# Cath
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 profile_dir_set

TODOCUMENT

=cut

has profile_dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskProfileDirSet,
	default => sub { Cath::Gemma::Disk::ProfileDirSet->new(); },
	handles => {
		aln_dir              => 'aln_dir',
		base_dir_and_project => 'base_dir_and_project',
		prof_dir             => 'prof_dir',
		starting_cluster_dir => 'starting_cluster_dir',
	},
);

=head2 scan_dir

TODOCUMENT

=cut

has scan_dir => (
	is  => 'lazy',
	isa => Path,
);


sub _insist_base_dir_and_project {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->base_dir_and_project()
		or confess "Must specify base_dir_and_project in ProfileDirSet if not specifying starting_cluster_dir, aln_dir and prof_dir";
	return $base_dir_and_project;
}

=head2 _build_scan_dir

TODOCUMENT

=cut

sub _build_scan_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->profile_dir_set()->base_dir_and_project()
		or confess "Must specify base_dir_and_project in member ProfileDirSet if not specifying scan_dir in GemmaDirSet";

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'scans' );
}


=head2 is_equal_to

TODOCUMENT

=cut

sub is_equal_to {
	state $check = compile( Object, CathGemmaDiskGemmaDirSet );
	my ( $self, $rhs ) = $check->( @ARG );

	return (
		$self->profile_dir_set()->is_equal_to( $rhs->profile_dir_set())
		&&
		$self->scan_dir()->stringify() eq $rhs->scan_dir()->stringify()
	);
}

=head2 is_set

TODOCUMENT

=cut

sub is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return (
		$self->profile_dir_set->is_set()
		&&
		$self->scan_dir()
	);
}

=head2 scan_filename_of_cluster_ids

TODOCUMENT

=cut

sub scan_filename_of_cluster_ids {
	state $check = compile( Object, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $self, $query_ids, $match_ids, $compass_profile_build_type ) = $check->( @ARG );

	return scan_filename_of_dir_and_cluster_ids(
		$self->scan_dir(),
		$query_ids,
		$match_ids,
		$compass_profile_build_type,
	);
}

=head2 get_starting_clusters

TODOCUMENT

=cut

sub get_starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return get_starting_clusters_of_starting_cluster_dir( $self->starting_cluster_dir() );
}

=head2 make_gemma_dir_set_of_base_dir_and_project

TODOCUMENT

=cut

sub make_gemma_dir_set_of_base_dir_and_project {
	state $check = compile( Invocant, Path, Str );
	my ( $proto, $base_dir, $project ) = $check->( @ARG );
	return Cath::Gemma::Disk::GemmaDirSet->new(
		profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir_and_project(
			$base_dir,
			$project
		)
	);
}


1;
