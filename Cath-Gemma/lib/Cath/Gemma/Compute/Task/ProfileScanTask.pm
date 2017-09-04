package Cath::Gemma::Compute::Task::ProfileScanTask;

use strict;
use warnings;

# Core
use Carp               qw/ confess                   /;
use English            qw/ -no_match_vars            /;
use List::Util         qw/ any min                   /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy /; # ***** TEMPORARY ******
use Object::Util;
use Path::Tiny;
use Type::Params       qw/ compile Invocant          /;
use Types::Path::Tiny  qw/ Path                      /;
use Types::Standard    qw/ ArrayRef Object Str Tuple /;

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Tool::CompassScanner;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaComputeTaskProfileScanTask
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

with ( 'Cath::Gemma::Compute::Task' );

=head2 starting_cluster_list_pairs

TODOCUMENT

=cut

has starting_cluster_list_pairs => (
	is          => 'ro',
	isa         => ArrayRef[Tuple[ArrayRef[Str],ArrayRef[Str]]],
	handles_via => 'Array',
	handles     => {
		is_empty       => 'is_empty',
		num_steps_impl => 'count',
		step_of_index  => 'get',
	},
	required    => 1,
);

=head2 num_steps

TODOCUMENT

This pass-through is to satisfy the corresponding 'requires' in Task,
which isn't satisfied by the 'handles' above

=cut

sub num_steps {
	my $self = shift;
	return $self->num_steps_impl();
}

=head2 compass_profile_build_type

TODOCUMENT

=cut

has compass_profile_build_type => (
	is       => 'ro',
	isa      => CathGemmaCompassProfileType,
	required => 1,
);

=head2 dir_set

TODOCUMENT

=cut

has dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskGemmaDirSet,
	default => sub { Cath::Gemma::Disk::GemmaDirSet->new(); },
	handles => {
		aln_dir              => 'aln_dir',
		prof_dir             => 'prof_dir',
		scan_dir             => 'scan_dir',
		starting_cluster_dir => 'starting_cluster_dir',
	},
	required => 1,
);

# =head2 id

# TODOCUMENT

# =cut

# sub id {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return generic_id_of_clusters( [ map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() } ] );
# }

# =head2 get_sub_task

# TODOCUMENT

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

=head2 id

TODOCUMENT

=cut

sub id {
	my $self = shift;
	return generic_id_of_clusters( [
		$self->compass_profile_build_type(),
		map {
			(
				id_of_starting_clusters( $ARG->[ 0 ] ),
				id_of_starting_clusters( $ARG->[ 1 ] ),
			);
		} @{ $self->starting_cluster_list_pairs() }
	] );
}

=head2 remove_already_present

TODOCUMENT

=cut

sub remove_already_present {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $starting_cluster_list_pairs = $self->starting_cluster_list_pairs();

	my @del_indices = grep {
		my $starting_cluster_list_pair = $starting_cluster_list_pairs->[ $ARG ];
		-s ( '' . $self->dir_set()->scan_filename_of_cluster_ids(
			$starting_cluster_list_pair->[ 0 ],
			$starting_cluster_list_pair->[ 1 ],
			$self->compass_profile_build_type()
		) )
	} ( 0 .. $#$starting_cluster_list_pairs );

	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @$starting_cluster_list_pairs, $reverse_index, 1 );
	}

	return $self;
}

=head2 total_num_starting_clusters

TODOCUMENT

=cut

sub total_num_starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0( map { scalar( @{ $ARG->[ 0 ] } ) + scalar( @{ $ARG->[ 1 ] } ); } @{ $self->starting_cluster_lists() } );
}

# =head2 total_num_comparisons

# TODOCUMENT

# =cut

# sub total_num_comparisons {

# }

=head2 execute_task

TODOCUMENT

=cut

sub execute_task {
	my ( $self, $exes ) = @ARG;

	return [
		map
		{
			my ( $query_ids, $match_ids ) = @$ARG;
			INFO 'Scanning '
				. scalar( @$query_ids )
				. ' query starting cluster(s) (beginning with '
				. join( ', ', @$query_ids[ 0 .. min( 20, $#$query_ids ) ] )
				. ') against '
				. scalar( @$match_ids )
				. ' starting cluster(s) (beginning with '
				. join( ', ', @$match_ids[ 0 .. min( 20, $#$match_ids ) ] )
				. ')'
				;
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

=head2 split_into_singles

TODOCUMENT

=cut

sub split_into_singles {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [
		map
			{ $self->$_clone( starting_cluster_list_pairs => [ $ARG ] ); }
			@{ $self->starting_cluster_list_pairs() }
	];
}

=head2 remove_duplicate_scan_tasks

TODOCUMENT

=cut

sub remove_duplicate_scan_tasks {
	state $check = compile( Invocant, ArrayRef[CathGemmaComputeTaskProfileScanTask] );
	my ( $proto, $scan_tasks ) = $check->( @ARG );

	if ( scalar( @$scan_tasks ) ) {
		my $compass_profile_build_type = $scan_tasks->[ 0 ]->compass_profile_build_type();
		my $dir_set                    = $scan_tasks->[ 0 ]->dir_set();

		if ( any { $ARG->compass_profile_build_type() ne $compass_profile_build_type } @$scan_tasks ) {
			confess "Cannot remove_duplicate_scan_tasks() for ProfileScanTasks with inconsistent compass_profile_build_type()s";
		}
		if ( any { ! $ARG->dir_set()->is_equal_to( $dir_set ) } @$scan_tasks ) {
			confess "Cannot remove_duplicate_scan_tasks() for ProfileScanTasks with inconsistent dir_set()s";
		}

		my %prev_seen_ids;
		foreach my $scan_task ( @$scan_tasks ) {

			my $starting_cluster_list_pairs = $scan_task->starting_cluster_list_pairs();
			my @del_indices = grep {
				my $pair              = $starting_cluster_list_pairs->[ $ARG ];
				my $id                = id_of_starting_clusters( $pair->[ 0 ] ) . '/' . id_of_starting_clusters( $pair->[ 1 ] );
				my $prev_seen         = $prev_seen_ids{ $id };
				$prev_seen_ids{ $id } = 1;
				$prev_seen;
			} ( 0 .. $#$starting_cluster_list_pairs );

			foreach my $reverse_index ( reverse( @del_indices ) ) {
				splice( @$starting_cluster_list_pairs, $reverse_index, 1 );
			}
		}
	}

	return $scan_tasks;
}

=head2 estimate_time_to_execute_step_of_index

TODOCUMENT

# TODO: Make this estimate time more sensibly than assuming 1 second per scan step

=cut

sub estimate_time_to_execute_step_of_index {
	my ( $self, $index ) = @ARG;
	my $step = $self->step_of_index( $index );
	return Time::Seconds->new( 1 );
}

=head2 make_batch_of_indices

TODOCUMENT

=cut

sub make_batch_of_indices {
	my ( $self, $start_index, $num_steps ) = @ARG;
	return Cath::Gemma::Compute::WorkBatch->new(
		scan_tasks => [
			$self->$_clone(
				starting_cluster_list_pairs => [ @{ $self->starting_cluster_list_pairs() } [ $start_index .. ( $start_index + $num_steps - 1 ) ] ]
			)
		],
	);
}

1;
