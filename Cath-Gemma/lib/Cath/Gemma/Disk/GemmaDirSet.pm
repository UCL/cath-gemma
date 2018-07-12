package Cath::Gemma::Disk::GemmaDirSet;

=head1 NAME

Cath::Gemma::Disk::GemmaDirSet - A bunch of directories, like ProfileDirSet plus a directory for scans

=cut

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

# Cath::Gemma
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
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
	handles => [ qw/
		aln_dir
		base_dir_and_project
		prof_dir
		starting_cluster_dir
	/ ],
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

=head2 assert_is_set

Check that all the directories are set and die if not

=cut

sub assert_is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	$self->profile_dir_set->assert_is_set();
	$self->scan_dir();
}

=head2 scan_filename_of_cluster_ids

TODOCUMENT

=cut

sub scan_filename_of_cluster_ids {
	state $check = compile( Object, ArrayRef[Str], ArrayRef[Str], CathGemmaProfileType );
	my ( $self, $query_ids, $match_ids, $profile_build_type ) = $check->( @ARG );

	return scan_filename_of_dir_and_cluster_ids(
		$self->scan_dir(),
		$query_ids,
		$match_ids,
		$profile_build_type,
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

Make a GemmaDirSet from the specified base_dir and project

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

=head2 make_gemma_dir_set_of_base_dir

Make a GemmaDirSet from the specified base_dir

=cut

sub make_gemma_dir_set_of_base_dir {
	state $check = compile( Invocant, Path );
	my ( $proto, $base_dir ) = $check->( @ARG );
	return Cath::Gemma::Disk::GemmaDirSet->new(
		profile_dir_set => Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir(
			$base_dir
		)
	);
}

1;
