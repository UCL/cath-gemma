package Cath::Gemma::Disk::ProfileDirSet;

=head1 NAME

Cath::Gemma::Disk::ProfileDirSet - A bunch of directories ( 'starting_cluster_dir', 'aln_dir' and 'prof_dir;) relating to profiles

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess                            /;
use English           qw/ -no_match_vars                     /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile Invocant                   /;
use Types::Path::Tiny qw/ Path                               /;
use Types::Standard   qw/ ArrayRef Maybe Object Optional Str /;

# Cath::Gemma
use Cath::Gemma::Disk::BaseDirAndProject;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
	CathGemmaHHSuiteProfileType
	CathGemmaCompassProfileType
	CathGemmaDiskBaseDirAndProject
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 base_dir_and_project

An optional base_dir_and_project which is a simple way to specify all the child directories
(using default sub directory names)

=cut

has base_dir_and_project => (
	is  => 'ro',
	isa => Maybe[CathGemmaDiskBaseDirAndProject],
);

=head2 starting_cluster_dir

The directory for starting clusters

=cut


=head2 aln_dir

The directory for alignments

=cut


=head2 prof_dir

The directory for COMPASS profiles

=cut

has [ qw/ starting_cluster_dir aln_dir prof_dir / ] => (
	is      => 'lazy',
	isa     => Path,
);

=head2 _insist_base_dir_and_project

TODOCUMENT

=cut

sub _insist_base_dir_and_project {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->base_dir_and_project()
		or confess "Must specify base_dir_and_project in ProfileDirSet if not specifying starting_cluster_dir, aln_dir and prof_dir";
	return $base_dir_and_project;
}

=head2 _build_starting_cluster_dir

A builder for the starting cluster directory (from the base_dir_and_project) if isn't directly specified

=cut

sub _build_starting_cluster_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'starting_clusters' );
}

=head2 _build_aln_dir

A builder for the alignment directory (from the base_dir_and_project) if isn't directly specified

=cut

sub _build_aln_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'alignments' );
}

=head2 _build_prof_dir

A builder for the profile directory (from the base_dir_and_project) if isn't directly specified

=cut

sub _build_prof_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'profiles' );
}

=head2 is_equal_to

Return whether this is the same as the specified CathGemmaDiskProfileDirSet

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

=head2 assert_is_set

Check that all the directories are set and die if not

=cut

sub assert_is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	$self->starting_cluster_dir();
	$self->aln_dir();
	$self->prof_dir();
}

=head2 alignment_filename_of_starting_clusters

Get the alignment file in this ProfileDirSet associated with the specified starting clusters

=cut

sub alignment_filename_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $starting_clusters ) = $check->( @ARG );

	return $self->aln_dir()->child( alignment_filebasename_of_starting_clusters( $starting_clusters ) );
}

=head2 prof_file_of_aln_file

Get the profile file in this ProfileDirSet associated with the specified alignment file

=cut

sub prof_file_of_aln_file {
	state $check = compile( Object, Path, Optional[CathGemmaProfileType] );
	my ( $self, $aln_file, $profile_build_type ) = $check->( @ARG );
	# uncoverable condition false
	$profile_build_type //= default_profile_build_type();
	return prof_file_of_prof_dir_and_aln_file(
		$self->prof_dir(),
		$aln_file,
		$profile_build_type,
	);
}

=head2 profile_file_of_starting_clusters

Get the profile file in this ProfileDirSet associated with the specified starting clusters

=cut

sub profile_file_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str], Optional[CathGemmaProfileType] );
	my ( $self, $starting_clusters, $profile_build_type ) = $check->( @ARG );
	# uncoverable condition false
	$profile_build_type //= default_profile_build_type();
	return $self->prof_file_of_aln_file(
		$self->alignment_filename_of_starting_clusters( $starting_clusters ),
		$profile_build_type,
	);
}

=head2 make_profile_dir_set_of_base_dir_and_project

Make a ProfileDirSet from the specified base_dir and project

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

=head2 make_profile_dir_set_of_base_dir

Make a ProfileDirSet from the specified base_dir

=cut

sub make_profile_dir_set_of_base_dir {
	state $check = compile( Invocant, Path );
	my ( $proto, $base_dir ) = $check->( @ARG );
	return Cath::Gemma::Disk::ProfileDirSet->new(
		base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
			base_dir => $base_dir
		),
	);
}

1;
