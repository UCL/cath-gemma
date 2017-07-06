package Cath::Gemma::Compute::WorkBatcher;

=head1 NAME

Cath::Gemma::Compute::WorkBatcher - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp               qw/ confess        /;
use English            qw/ -no_match_vars /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Object::Util;
use Type::Params       qw/ compile        /;
use Types::Standard    qw/ Int Object     /;

# Cath
use Cath::Gemma::Compute::WorkBatcherState;
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatchList
	TimeSeconds
	/;

=head2 est_time_per_batch

=cut

has est_time_per_batch => (
	is      => 'rwp',
	isa     => TimeSeconds,
	default => sub { Time::Seconds->new( 150 ); },
);

=head2 rebatch

=cut

sub rebatch {
	state $check = compile( Object, CathGemmaComputeWorkBatchList );
	my ( $self, $work_batches ) = $check->( @ARG );

	my $batcher_state = Cath::Gemma::Compute::WorkBatcherState->new(
		build_batches => [],
		scan_batches  => [],
	);

	if ( ! $work_batches->dependencies_empty() ) {
		confess "Cannot currently handle existing dependencies in a WorkBatchList as it's being rebatched";
	}

	foreach my $work_batch ( @{ $work_batches->batches() } ) {
		$batcher_state->add_batch(
			$work_batch,
			$self->est_time_per_batch()
		);
	}
	
	return $batcher_state->get_new_batch_list();


	# my $num_new_profiles       = $profile_task->num_profiles();
	# my $profile_tasks          = $self->profile_tasks();

	# my $num_free_profiles_in_last_batch =
	# 	( scalar( @$profile_tasks ) > 0 )
	# 	? $self->num_steps_per_batch() - $profile_tasks->[ -1 ]->num_profiles()
	# 	: 0;

	# # if ( scalar( @$profile_tasks ) > 0 ) {
	# # 	my @bob = map { $ARG->num_profiles(); } @$profile_tasks;
	# # }

	# my $num_in_fillup_batch = min( $num_free_profiles_in_last_batch, $num_new_profiles );

	# if ( $num_in_fillup_batch > 0 ) {
	# 	my $prev_last_profile_task = pop @$profile_tasks;
	# 	push
	# 		@{ $profile_tasks },
	# 		Cath::Gemma::Compute::WorkBatch->new(
	# 			profile_tasks => [
	# 				@{ $prev_last_profile_task->profile_tasks() },
	# 				$profile_task->$_clone(
	# 					starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ 0 .. ( $num_in_fillup_batch - 1 ) ] ],
	# 				)
	# 			]
	# 		);
	# }

	# my $num_remaining_profiles = $num_new_profiles - $num_in_fillup_batch;
	# my $num_remaining_batches  = (    int( $num_remaining_profiles / $self->num_steps_per_batch() )
	#                                + ( ( ( $num_remaining_profiles % $self->num_steps_per_batch() ) > 0 ) ? 1 : 0 ) );
	# for (my $batch_ctr = 0; $batch_ctr < $num_remaining_batches; ++$batch_ctr) {
	# 	my $batch_begin_index        =      $num_in_fillup_batch + (   $batch_ctr       * $self->num_steps_per_batch() );
	# 	my $batch_one_past_end_index = min( $num_in_fillup_batch + ( ( $batch_ctr + 1 ) * $self->num_steps_per_batch() ), $num_new_profiles );
	# 	push
	# 		@{ $profile_tasks },

	# 		Cath::Gemma::Compute::WorkBatch->new(
	# 			profile_tasks => [
	# 				$profile_task->$_clone(
	# 					starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ $batch_begin_index .. ( $batch_one_past_end_index - 1 ) ] ],
	# 				),
	# 			]
	# 		);
	# }
}

1;
