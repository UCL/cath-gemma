package Cath::Gemma::Disk::TreeDirSet;

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
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskTreeDirSet
/;
use Cath::Gemma::Util;

=head2 gemma_dir_set

=cut

has gemma_dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskGemmaDirSet,
	default => sub { Cath::Gemma::Disk::GemmaDirSet->new(); },
	handles => {
		aln_dir              => 'aln_dir',
		base_dir_and_project => 'base_dir_and_project',
		prof_dir             => 'prof_dir',
		profile_dir_set      => 'profile_dir_set',
		scan_dir             => 'scan_dir',
		starting_cluster_dir => 'starting_cluster_dir',
	},
);

=head2 tree_dir

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

=cut

sub _build_tree_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir_and_project = $self->gemma_dir_set()->base_dir_and_project()
		or confess "Must specify base_dir_and_project in member GemmaDirSet if not specifying tree_dir in TreeDirSet";

	return $self->_insist_base_dir_and_project()->get_project_subdir_of_subdir( 'trees' );
}


=head2 is_equal_to

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

=head2 is_set

=cut

sub is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return (
		$self->gemma_dir_set->is_set()
		&&
		$self->tree_dir()
	);
}

# =head2 scan_filename_of_cluster_ids

# =cut

# sub scan_filename_of_cluster_ids {
# 	state $check = compile( Object, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
# 	my ( $self, $query_ids, $match_ids, $compass_profile_build_type ) = $check->( @ARG );

# 	return scan_filename_of_dir_and_cluster_ids(
# 		$self->tree_dir(),
# 		$query_ids,
# 		$match_ids,
# 		$compass_profile_build_type,
# 	);
# }

=head2 make_tree_dir_set_of_base_dir_and_project

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