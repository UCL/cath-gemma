package Cath::Gemma::Disk::ProfileDirSet;

use strict;
use warnings;

# Core
use Carp              qw/ confess                   /;
use English           qw/ -no_match_vars            /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile Invocant          /;
use Types::Path::Tiny qw/ Path                      /;
use Types::Standard   qw/ ArrayRef Maybe Object Str /;

# Cath
use Cath::Gemma::Disk::BaseDirAndProject;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskBaseDirAndProject
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 base_dir_and_project

TODOCUMENT

=cut

has base_dir_and_project => (
	is  => 'ro',
	isa => Maybe[CathGemmaDiskBaseDirAndProject],
);

=head2 starting_cluster_dir

TODOCUMENT

=cut


=head2 aln_dir

TODOCUMENT

=cut


=head2 prof_dir

TODOCUMENT

=cut

has [ qw/ starting_cluster_dir aln_dir prof_dir / ] => (
	is      => 'lazy',
	isa     => Path,
);

sub _insist_base_dir_and_project {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->base_dir_and_project()
		or confess "Must specify base_dir_and_project in ProfileDirSet if not specifying starting_cluster_dir, aln_dir and prof_dir";
	return $base_dir_and_project;
}

=head2 _build_starting_cluster_dir

TODOCUMENT

=cut

sub _build_starting_cluster_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'starting_clusters' );
}

=head2 _build_aln_dir

TODOCUMENT

=cut

sub _build_aln_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'alignments' );
}

=head2 _build_prof_dir

TODOCUMENT

=cut

sub _build_prof_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'profiles' );
}

=head2 is_equal_to

TODOCUMENT

=cut

sub is_equal_to {
	state $check = compile( Object, CathGemmaDiskProfileDirSet );
	my ( $self, $rhs ) = $check->( @ARG );

	return (
		$self->starting_cluster_dir()->stringify() eq $rhs->starting_cluster_dir()->stringify()
		&&
		$self->aln_dir()->stringify()              eq $rhs->aln_dir()->stringify()
		&&
		$self->prof_dir()->stringify()             eq $rhs->prof_dir()->stringify()
	);
}

=head2 is_set

TODOCUMENT

=cut

sub is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return (
		defined( $self->starting_cluster_dir() )
		&&
		defined( $self->aln_dir()              )
		&&
		defined( $self->prof_dir()             )
	);
}

=head2 alignment_filename_of_starting_clusters

TODOCUMENT

=cut

sub alignment_filename_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $starting_clusters ) = $check->( @ARG );

	if ( ! $self->is_set() ) {
		confess "Unable to use ProfileDirSet that isn't set";
	}

	return $self->aln_dir()->child( alignment_filebasename_of_starting_clusters( $starting_clusters ) );
}

=head2 prof_file_of_aln_file

TODOCUMENT

=cut

sub prof_file_of_aln_file {
	state $check = compile( Object, Path, CathGemmaCompassProfileType );
	my ( $self, $aln_file, $compass_profile_build_type ) = $check->( @ARG );
	return prof_file_of_prof_dir_and_aln_file(
		$self->prof_dir(),
		$aln_file,
		$compass_profile_build_type,
	);
}

=head2 compass_file_of_starting_clusters

TODOCUMENT

=cut

sub compass_file_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $self, $starting_clusters, $compass_profile_build_type ) = $check->( @ARG );
	return $self->prof_file_of_aln_file(
		$self->alignment_filename_of_starting_clusters( $starting_clusters ),
		$compass_profile_build_type,
	);
}

=head2 make_profile_dir_set_of_base_dir_and_project

TODOCUMENT

=cut

sub make_profile_dir_set_of_base_dir_and_project {
	state $check = compile( Invocant, Path, Str );
	my ( $proto, $base_dir, $project ) = $check->( @ARG );
	return Cath::Gemma::Disk::ProfileDirSet->new(
		base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
			base_dir => $base_dir,
			project  => $project,
		),
	);
}

1;
