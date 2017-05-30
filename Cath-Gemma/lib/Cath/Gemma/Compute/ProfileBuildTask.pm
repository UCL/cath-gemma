package Cath::Gemma::Compute::ProfileBuildTask;

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars                   /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile                          /;
use Types::Path::Tiny  qw/ Path                             /;
use Types::Standard    qw/ ArrayRef Int Object Optional Str /;

# Cath
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Types qw/
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 starting_cluster_lists

=cut

has starting_cluster_lists => (
	is          => 'ro',
	isa         => ArrayRef[ArrayRef[Str]],
	handles_via => 'Array',
	handles     => {
		is_empty                   => 'is_empty',
		num_profiles               => 'count',
		starting_clusters_of_index => 'get',
	}
);

=head2 dir_set

=cut

has dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskProfileDirSet,
	default => sub { CathGemmaDiskProfileDirSet->new(); },
	handles => {
		starting_cluster_dir => 'starting_cluster_dir',
		aln_dir              => 'aln_dir',
		prof_dir             => 'prof_dir',
	},
);

=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return generic_id_of_clusters( [ map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() } ] );
}

=head2 get_sub_task

=cut

sub get_sub_task {
	state $check = compile( Object, Int, Int );
	my ( $self, $begin, $end ) = $check->( @ARG );

	return __PACKAGE__->new(
		starting_cluster_lists => 0,
		starting_cluster_dir   => $self->starting_cluster_dir(),
		aln_dir                => $self->aln_dir(),
		prof_dir               => $self->prof_dir(),
	);
}

=head2 total_num_starting_clusters

=cut

sub total_num_starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0( map { scalar( @$ARG ); } @{ $self->starting_cluster_lists() } );
}

=head2 execute_task

=cut

sub execute_task {
	state $check = compile( Object, CathGemmaDiskExecutables, Optional[Path] );
	my ( $self, $exes, $tmp_dir ) = $check->( @ARG );

	$tmp_dir //= $self->aln_dir();

	if ( ! $self->dir_set()->is_set() ) {
		warn "Cannot execute_task on a ProfileBuildTask that doesn't have all its directories configured";
	}

	return [
		map
		{
			my $starting_clusters = $ARG;
			Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
				$exes,
				$starting_clusters,
				$self->dir_set(),
				$tmp_dir
			);
		}
		@{ $self->starting_cluster_lists() },
	];
}

1;
