package Cath::Gemma::Disk::TreeDirSet;

=head1 NAME

Cath::Gemma::Disk::TreeDirSet - A bunch of directories, like GemmaDirSet plus a directory for trees

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
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskTreeDirSet
/;
use Cath::Gemma::Util;

=head2 gemma_dir_set

TODOCUMENT

=cut

has gemma_dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskGemmaDirSet,
	default => sub { Cath::Gemma::Disk::GemmaDirSet->new(); },
	handles => [ qw/
		aln_dir
		base_dir_and_project
		get_starting_clusters
		prof_dir
		profile_dir_set
		scan_dir
		starting_cluster_dir
	/ ],
);

=head2 tree_dir

TODOCUMENT

=cut

has tree_dir => (
	is  => 'lazy',
	isa => Path,
);


sub _insist_base_dir_and_project {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->base_dir_and_project()
		or confess "Must specify base_dir_and_project in GemmaDirSet if not specifying starting_cluster_dir, aln_dir and prof_dir";
	return $base_dir_and_project;
}

=head2 _build_tree_dir

TODOCUMENT

=cut

sub _build_tree_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->gemma_dir_set()->base_dir_and_project()
		or confess "Must specify base_dir_and_project in member GemmaDirSet if not specifying tree_dir in TreeDirSet";

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'trees' );
}


=head2 is_equal_to

TODOCUMENT

=cut

sub is_equal_to {
	state $check = compile( Object, CathGemmaDiskTreeDirSet );
	my ( $self, $rhs ) = $check->( @ARG );

	return (
		$self->gemma_dir_set()->is_equal_to( $rhs->gemma_dir_set())
		&&
		$self->tree_dir()->stringify() eq $rhs->tree_dir()->stringify()
	);
}

=head2 assert_is_set

Check that all the directories are set and die if not

=cut

sub assert_is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	$self->gemma_dir_set->assert_is_set();
	$self->tree_dir();
}

=head2 make_tree_dir_set_of_base_dir_and_project

TODOCUMENT

=cut

sub make_tree_dir_set_of_base_dir_and_project {
	state $check = compile( Invocant, Path, Str );
	my ( $proto, $base_dir, $project ) = $check->( @ARG );
	return Cath::Gemma::Disk::TreeDirSet->new(
		gemma_dir_set => Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir_and_project(
			$base_dir,
			$project
		)
	);
}


1;
