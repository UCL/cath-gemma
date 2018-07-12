package Cath::Gemma::Compute::WorkBatcherState;

=head1 NAME

Cath::Gemma::Compute::WorkBatcherState - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars      /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy               /;
use Type::Params        qw/ compile             /;
use Types::Standard     qw/ ArrayRef Int Object /;

# Cath::Gemma
use Cath::Gemma::Types  qw/
	CathGemmaComputeTaskProfileBuildTask
	CathGemmaComputeTaskProfileScanTask
	CathGemmaComputeTask
	CathGemmaComputeWorkBatch
	TimeSeconds
	/;
use Cath::Gemma::Util;

=head2 build_batches

TODOCUMENT

=cut

has build_batches => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaComputeWorkBatch],
	handles_via => 'Array',
	handles     => {
		build_batches_is_empty => 'is_empty',
		num_build_batches      => 'count',
		build_batch_of_index   => 'get',
	}
);

=head2 scan_batches

TODOCUMENT

=cut

has scan_batches => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaComputeWorkBatch],
	handles_via => 'Array',
	handles     => {
		scan_batches_is_empty => 'is_empty',
		num_scan_batches      => 'count',
		scan_batch_of_index   => 'get',
	}
);

=head2 indices_of_build_batches_needed_by_scan_batches

TODOCUMENT

=cut

has indices_of_build_batches_needed_by_scan_batches => (
	is      => 'rwp',
	isa     => ArrayRef[ArrayRef[Int]],
	default => sub { [ ]; },
);

=head2 add_batch

TODOCUMENT

=cut

sub add_batch {
	state $check = compile( Object, CathGemmaComputeWorkBatch, TimeSeconds );
	my ( $self, $work_batch, $estimate_duration_per_batch ) = $check->( @ARG );

	my $build_tasks = $work_batch->profile_tasks();
	my $scan_tasks  = $work_batch->scan_tasks();

	if ( scalar( @$build_tasks ) > 0 ) {
		INFO 'Rebatching: adding ' . scalar( @$build_tasks ) . ' build tasks';
	}
	my $new_build_batches = $self->_add_build_tasks( $build_tasks, $estimate_duration_per_batch );
	if ( scalar( @$scan_tasks ) > 0 ) {
		use Data::Dumper;
		INFO 'Rebatching: adding ' . scalar( @$scan_tasks ) . ' scan tasks with dependencies ' . Dumper( $new_build_batches );
	}
	$self->_add_scan_tasks( $scan_tasks, $new_build_batches, $estimate_duration_per_batch );
}

=head2 get_new_batch_list

TODOCUMENT

=cut

sub get_new_batch_list {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $num_build_batches = $self->num_build_batches();
	my $scans_deps_arrays = $self->indices_of_build_batches_needed_by_scan_batches();

	# use Carp qw/ confess /;
	# use Data::Dumper;
	# confess Dumper( $scans_deps_arrays ) . ' ';

	return Cath::Gemma::Compute::WorkBatchList->new(
		batches => [
			@{ $self->build_batches() },
			@{ $self->scan_batches () },
		],

		dependencies => [
			# An empty dependencies array for each of the build batches
			( [] ) x $num_build_batches,

			# A dependencies array for each of the scan indices
			map
				{ _get_final_dependency_offsets( $ARG, $scans_deps_arrays->[ $ARG ] // [], $num_build_batches ); }
				( 0 .. $#$scans_deps_arrays )
		],
	);
}

=head2 _get_final_dependency_offsets

TODOCUMENT

=cut

# TODO: Add tests:
# * _get_final_dependency_offsets( 0, [ 0, 1, 2 ], 3 ) should return [ 3, 2, 1 ]
# * _get_final_dependency_offsets( 1, [ 0, 1, 2 ], 3 ) should return [ 4, 3, 2 ]
# * _get_final_dependency_offsets( 2, [ 0, 1, 2 ], 3 ) should return [ 5, 4, 3 ]

sub _get_final_dependency_offsets {
	state $check = compile( Int, ArrayRef[Int], Int );
	my ( $scans_batch_index, $scans_deps, $num_build_batches ) = $check->( @ARG );

	return [
		map
			{
				$scans_batch_index + $num_build_batches - $ARG
			}
			@$scans_deps
	];
}

=head2 _add_build_tasks

TODOCUMENT

=cut

sub _add_build_tasks {
	state $check = compile( Object, ArrayRef[CathGemmaComputeTaskProfileBuildTask], TimeSeconds );
	my ( $self, $build_tasks, $estimate_duration_per_batch ) = $check->( @ARG );

	return $self->_add_in_tasks( $self->build_batches(), $build_tasks, $estimate_duration_per_batch );
}

=head2 _add_scan_tasks

TODOCUMENT

=cut

sub _add_scan_tasks {
	state $check = compile( Object, ArrayRef[CathGemmaComputeTaskProfileScanTask], ArrayRef[Int], TimeSeconds );
	my ( $self, $scan_tasks, $build_batch_indices, $estimate_duration_per_batch ) = $check->( @ARG );

	my $scan_batch_indices = $self->_add_in_tasks( $self->scan_batches(), $scan_tasks, $estimate_duration_per_batch );

	$self->set_indices( $scan_batch_indices, $build_batch_indices );
}

=head2 set_indices

TODOCUMENT

=cut

sub set_indices {
	state $check = compile( Object, ArrayRef[Int], ArrayRef[Int] );
	my ( $self, $scan_batch_indices, $build_batch_indices ) = $check->( @ARG );

	foreach my $scan_batch_index ( @$scan_batch_indices ) {
		my @indices = sort { $a <=> $b } unique_by_hashing(
			@{ $self->indices_of_build_batches_needed_by_scan_batches()->[ $scan_batch_index ] // [] },
			@$build_batch_indices
		);

		use Data::Dumper;
		# warn "dep indices : " . Dumper( [ $build_batch_indices, \@indices ] );

		$self->indices_of_build_batches_needed_by_scan_batches()->[ $scan_batch_index ] = \@indices;
	}
}

=head2 _add_in_tasks

TODOCUMENT

=cut

sub _add_in_tasks {
	state $check = compile( Object, ArrayRef[CathGemmaComputeWorkBatch], ArrayRef[CathGemmaComputeTask], TimeSeconds );
	my ( $self, $batches, $build_tasks, $estimate_duration_per_batch ) = $check->( @ARG );

	return [ sort { $a <=> $b } unique_by_hashing(
		# Add in task and append the resulting new task batches' indices
		map
		{ ( @{ $self->_add_in_task( $batches, $ARG, $estimate_duration_per_batch ) } ); }
		@$build_tasks
	) ];
}

=head2 _add_in_task

TODOCUMENT

=cut

sub _add_in_task {
	state $check = compile( Object, ArrayRef[CathGemmaComputeWorkBatch], CathGemmaComputeTask, TimeSeconds );
	my ( $self, $batches, $build_task, $estimate_duration_per_batch ) = $check->( @ARG );

	my $num_batches_at_start = scalar( @$batches );

	my $batch_up_results = $build_task->batch_up(
		( scalar( @$batches ) > 0 ) ? $batches->[ -1 ] : undef,
		$estimate_duration_per_batch
	);

	my @new_task_batch_indices = ();

	my ( $prev_appendee, $new_batches ) = @$batch_up_results;

	if ( $prev_appendee ) {
		$batches->[ -1 ]->append( $prev_appendee );
		push @new_task_batch_indices, $#$batches;
	}

	push @$batches, @$new_batches;

	push @new_task_batch_indices, ( $num_batches_at_start .. ( $num_batches_at_start + $#$new_batches ) );

	return \@new_task_batch_indices;
}

# =head2 rebatch

# TODOCUMENT

# =cut

# sub rebatch {
# 	state $check = compile( Object, CathGemmaComputeWorkBatchList );
# 	my ( $self, $work_batches ) = $check->( @ARG );

# 	my $num_new_profiles         = $profile_task->num_profiles();
# 	my $profile_tasks          = $self->profile_tasks();
# 	my $num_profiles_in_new_task = $profile_task->num_profiles();

# 	my $num_free_profiles_in_last_batch =
# 		( scalar( @$profile_tasks ) > 0 )
# 		? $self->profile_task_size() - $profile_tasks->[ -1 ]->num_profiles()
# 		: 0;

# 	if ( scalar( @$profile_tasks ) > 0 ) {
# 		my @bob = map { $ARG->num_profiles(); } @$profile_tasks;
# 	}

# 	my $num_in_fillup_batch = min( $num_free_profiles_in_last_batch, $num_new_profiles );

# 	if ( $num_in_fillup_batch > 0 ) {
# 		my $prev_last_profile_task = pop @$profile_tasks;
# 		push
# 			@{ $profile_tasks },
# 			Cath::Gemma::Compute::WorkBatch->new(
# 				profile_tasks => [
# 					@{ $prev_last_profile_task->profile_tasks() },
# 					$profile_task->$_clone(
# 						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ 0 .. ( $num_in_fillup_batch - 1 ) ] ],
# 					)
# 				]
# 			);
# 	}

# 	my $num_remaining_profiles = $num_new_profiles - $num_in_fillup_batch;
# 	my $num_remaining_batches  = (    int( $num_remaining_profiles / $self->profile_task_size() )
# 	                               + ( ( ( $num_remaining_profiles % $self->profile_task_size() ) > 0 ) ? 1 : 0 ) );
# 	for (my $batch_ctr = 0; $batch_ctr < $num_remaining_batches; ++$batch_ctr) {
# 		my $batch_begin_index        =      $num_in_fillup_batch + (   $batch_ctr       * $self->profile_task_size() );
# 		my $batch_one_past_end_index = min( $num_in_fillup_batch + ( ( $batch_ctr + 1 ) * $self->profile_task_size() ), $num_new_profiles );
# 		push
# 			@{ $profile_tasks },

# 			Cath::Gemma::Compute::WorkBatch->new(
# 				profile_tasks => [
# 					$profile_task->$_clone(
# 						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ $batch_begin_index .. ( $batch_one_past_end_index - 1 ) ] ],
# 					),
# 				]
# 			);
# 	}
# }

1;
