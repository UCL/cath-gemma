package Cath::Gemma::Compute::ProfileBuildTask;

use strict;
use warnings;

# Core
use Digest::MD5        qw/ md5_hex                          /;
use English            qw/ -no_match_vars                   /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
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
);

=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return md5_hex( map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() } );
}

=head2 get_sub_task

=cut

sub get_sub_task {
	state $check = compile( Object, Int, Int );
	my ( $self, $begin, $end ) = $check->( @ARG );

	return __PACKAGE__->new(
		starting_cluster_lists => 0,
		starting_cluster_dir   => $self->starting_cluster_dir(),
		aln_dest_dir           => $self->aln_dest_dir(),
		prof_dest_dir          => $self->prof_dest_dir(),
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

	my $starting_cluster_lists = $self->starting_cluster_lists();
	my $starting_cluster_dir   = $self->starting_cluster_dir();
	my $aln_dest_dir           = $self->aln_dest_dir();
	my $prof_dest_dir          = $self->prof_dest_dir();
	$tmp_dir                 //= $aln_dest_dir;

	return [
		map
		{
			my $starting_clusters = $ARG;
			Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
				$exes,
				$starting_clusters,
				$starting_cluster_dir,
				$aln_dest_dir,
				$prof_dest_dir,
				$tmp_dir
			);
		}
		@$starting_cluster_lists
	];
}

1;
