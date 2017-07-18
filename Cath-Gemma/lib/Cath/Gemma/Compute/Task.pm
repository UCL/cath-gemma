package Cath::Gemma::Compute::Task;

=head1 NAME

Cath::Gemma::Compute::Task - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess          /;
use English             qw/ -no_match_vars   /;
use List::Util          qw/ sum0             /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy            /;
use Type::Params        qw/ compile          /;
use Types::Standard     qw/ Int Object Maybe /;

# Cath
use Cath::Gemma::Types  qw/
	CathGemmaComputeBatchingPolicy
	CathGemmaComputeWorkBatch
	TimeSeconds
/;
use Cath::Gemma::Util;

=head2 requires num_steps

=cut

requires 'num_steps';


=head2 requires estimate_time_to_execute_step_of_index

=cut

requires 'estimate_time_to_execute_step_of_index';


=head2 estimate_time_to_execute_step_of_index

This is slightly dodgy and wouldn't pass in C++
(because it gets different return types from different derived classes' step_of_index() methods
 and then passes them to the  different  it calls step_of_index()
which returns a different

=cut

before estimate_time_to_execute_step_of_index => sub {
	state $check = compile( Object, Int );
	my ( $self, $index ) = $check->( @ARG );
	if ( $index >= $self->num_steps() ) {
		confess
			  'Unable to estimate_time_to_execute_step_of_index() because the index '
			  . $index . ' is out of range in a task of '
			  . $self->num_steps() . ' steps';
	}
};

=head2 estimate_num_steps_to_fill_time_from_index

=cut

sub estimate_num_steps_to_fill_time_from_index {
	state $check = compile( Object, Int, TimeSeconds, CathGemmaComputeBatchingPolicy );
	my ( $self, $start_index, $duration, $batching_policy ) = $check->( @ARG );

	my $total_time = Time::Seconds->new( 0 );
	my $num_steps  = 0;
	while ( $start_index + $num_steps < $self->num_steps() ) {
		$total_time += $self->estimate_time_to_execute_step_of_index( $start_index + $num_steps );
		if ( $total_time > $duration ) {
			last;
		}
		++$num_steps;
	}

	return ( ( $batching_policy eq 'allow_overflow_to_ensure_non_empty' ) && $num_steps == 0 )
		? 1
		: $num_steps;
}


=head2 requires make_batch_of_indices

=cut

requires 'make_batch_of_indices';

=head2 before make_batch_of_indices

=cut

before make_batch_of_indices => sub {
	state $check = compile( Object, Int, Int );

	my ( $self, $start_index, $num_steps ) = $check->( @ARG );

	if ( $start_index < 0 ) {
		confess 'make_batch_of_indices() was called with a negative start_index ' . $start_index;
	}
	if ( $num_steps < 0 ) {
		confess 'make_batch_of_indices() was called with a negative number of steps' . $num_steps;
	}
	elsif ( $num_steps == 0 ) {
		WARN 'make_batch_of_indices() has been requested to generate a batch of 0 steps';
	}
};

=head2 batch_up

=cut

sub batch_up {
	state $check = compile( Object, Maybe[CathGemmaComputeWorkBatch], TimeSeconds );
	my ( $self, $prev_batch_opt, $estimate_duration_per_batch ) = $check->( @ARG );

	my $start_index = 0;

	my $do_one = sub {
		state $check = compile( Object, TimeSeconds, CathGemmaComputeBatchingPolicy );
		my ( $self, $duration, $batching_policy ) = $check->( @ARG );

		my $num_steps = $self->estimate_num_steps_to_fill_time_from_index(
			$start_index,
			$duration,
			$batching_policy
		);
		my @result = ( $start_index, $num_steps );
		$start_index += $num_steps;
		return \@result;
	};

	my $prev_appendee;
	if ( $prev_batch_opt ) {
		my $capped_prev_batch_time = min_time_seconds(
			$prev_batch_opt->estimate_time_to_execute(),
			$estimate_duration_per_batch
		);
		my $start_and_num_steps = $do_one->(
			$self,
			$estimate_duration_per_batch - $capped_prev_batch_time,
			'permit_empty__forbid_overflow'
		);
		if ( $start_and_num_steps->[ 1 ] ) {
			$prev_appendee = $self->make_batch_of_indices( @$start_and_num_steps );
		}

		# my $capped_prev_batch_time = min_time_seconds(
		# 	$prev_batch_opt->estimate_time_to_execute(),
		# 	$estimate_duration_per_batch
		# );

		# my $num_steps = $self->estimate_num_steps_to_fill_time_from_index(
		# 	$start_index,
		# 	$estimate_duration_per_batch - $capped_prev_batch_time,
		# 	'permit_empty__forbid_overflow'
		# );
		# if ( $num_steps > 0 ) {
		# 	$prev_appendee  = $self->make_batch_of_indices( $start_index, $num_steps );
		# 	$start_index   += $num_steps;
		# }
	}

	my @start_and_num_of_new_batches;
	while ( $start_index < $self->num_steps() ) {
		push @start_and_num_of_new_batches, $do_one->(
			$self,
			$estimate_duration_per_batch,
			'allow_overflow_to_ensure_non_empty'
		);

		# my $num_steps = $self->estimate_num_steps_to_fill_time_from_index(
		# 	$start_index,
		# 	$estimate_duration_per_batch,
		# 	'allow_overflow_to_ensure_non_empty'
		# );
		# push @start_and_num_of_new_batches, [ $start_index, $num_steps ];
		# $start_index += $num_steps;
	}

	return [
		$prev_appendee,
		[
			map
			{ $self->make_batch_of_indices( @$ARG ); }
			@start_and_num_of_new_batches
		]
	];
};


=head2 before estimate_time_to_execute

=cut

sub estimate_time_to_execute {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0( map { $self->estimate_time_to_execute_step_of_index( $ARG ); } ( 0 .. ( $self->num_steps() - 1 ) ) );
}


=head2 estimate_time_to_execute_batch

=cut

sub estimate_time_to_execute_batch {
	state $check = compile( Object, CathGemmaComputeWorkBatch );
	$check->( @ARG );
}


1;
