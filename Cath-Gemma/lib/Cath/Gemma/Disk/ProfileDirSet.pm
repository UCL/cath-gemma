package Cath::Gemma::Disk::ProfileDirSet;

use strict;
use warnings;

# Core
use Carp              qw/ confess             /;
use English           qw/ -no_match_vars      /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile             /;
use Types::Path::Tiny qw/ Path                /;
use Types::Standard   qw/ ArrayRef Object Str /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaCompassProfileType /;
use Cath::Gemma::Util;

=head2 starting_cluster_dir

=cut


=head2 aln_dir

=cut


=head2 prof_dir

=cut


has [ qw/ starting_cluster_dir aln_dir prof_dir / ] => (
	is  => 'ro',
	isa => Path,
);

=head2 is_set

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

=cut

sub compass_file_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $self, $starting_clusters, $compass_profile_build_type ) = $check->( @ARG );
	return $self->prof_file_of_aln_file(
		$self->alignment_filename_of_starting_clusters( $starting_clusters ),
		$compass_profile_build_type,
	);
}

1;
