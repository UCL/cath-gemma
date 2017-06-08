package Cath::Gemma::Compute::ProfileScanTask;

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars            /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile                   /;
use Types::Path::Tiny  qw/ Path                      /;
use Types::Standard    qw/ ArrayRef Object Str Tuple /;

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 starting_cluster_list_pairs

=cut

has starting_cluster_list_pairs => (
	is          => 'ro',
	isa         => ArrayRef[Tuple[ArrayRef[Str],ArrayRef[Str]]],
	handles_via => 'Array',
	handles     => {
		is_empty                            => 'is_empty',
		num_scans                           => 'count',
		starting_cluster_list_pair_of_index => 'get',
	}
);

=head2 compass_profile_build_type

=cut

has compass_profile_build_type => (
	is       => 'ro',
	isa      => CathGemmaCompassProfileType,
	required => 1,
);

=head2 dir_set

=cut

has dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskGemmaDirSet,
	default => sub { CathGemmaDiskGemmaDirSet->new(); },
	handles => {
		aln_dir              => 'aln_dir',
		prof_dir             => 'prof_dir',
		scan_dir             => 'scan_dir',
		starting_cluster_dir => 'starting_cluster_dir',
	},
);

# =head2 id

# =cut

# sub id {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return generic_id_of_clusters( [ map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() } ] );
# }

# =head2 get_sub_task

# =cut

# sub get_sub_task {
# 	state $check = compile( Object, Int, Int );
# 	my ( $self, $begin, $end ) = $check->( @ARG );

# 	return __PACKAGE__->new(
# 		starting_cluster_lists => 0,
# 		starting_cluster_dir   => $self->starting_cluster_dir(),
# 		aln_dir                => $self->aln_dir(),
# 		prof_dir               => $self->prof_dir(),
# 	);
# }

=head2 total_num_starting_clusters

=cut

sub total_num_starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0( map { scalar( @{ $ARG->[ 0 ] } ) + scalar( @{ $ARG->[ 1 ] } ); } @{ $self->starting_cluster_lists() } );
}

# =head2 total_num_comparisons

# =cut

# sub total_num_comparisons {

# }

=head2 execute_task

=cut

sub execute_task {
	state $check = compile( Object, CathGemmaDiskExecutables );
	my ( $self, $exes ) = $check->( @ARG );

	if ( ! $self->dir_set()->is_set() ) {
		warn "Cannot execute_task on a ProfileScanTask that doesn't have all its directories configured";
	}

	return [
		map
		{
			my ( $query_ids, $match_ids ) = @$ARG;
			Cath::Gemma::Tool::CompassScanner->compass_scan_to_file(
				$exes,
				$query_ids,
				$match_ids,
				$self->dir_set(),
				$self->compass_profile_build_type(),
			);
		}
		@{ $self->starting_cluster_list_pairs() },
	];
}

=head2 split

=cut

sub split {
	state $check = compile( Object );
	my ( $self  ) = $check->( @ARG );

	return [
		map
			{
				Cath::Gemma::Compute::ProfileScanTask->new(
					compass_profile_build_type  => $self->compass_profile_build_type(),
					dir_set                     => $self->dir_set(),
					starting_cluster_list_pairs => [ $ARG ],
				);
			}
			@{ $self->starting_cluster_list_pairs() }
	];
}

1;
