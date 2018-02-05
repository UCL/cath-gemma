package Cath::Gemma::Executor::DirectExecutor;

=head1 NAME

Cath::Gemma::Executor::DirectExecutor - Execute a Cath::Gemma::Compute::WorkBatchList locally (ie directly)

=cut

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars           /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                    /;
use Types::Standard     qw/ Int                      /;

# Cath::Gemma
use Cath::Gemma::Compute::TaskThreadPooler;
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Types  qw/ CathGemmaDiskExecutables /;
use Cath::Gemma::Util;

with ( 'Cath::Gemma::Executor' );

=head2 exes

TODOCUMENT

=cut

has exes => (
	is      => 'ro',
	isa     => CathGemmaDiskExecutables,
	default => sub { Cath::Gemma::Disk::Executables->new(); },
);

=head2 max_num_threads

TODOCUMENT

=cut

has max_num_threads => (
	is      => 'ro',
	isa     => Int,
	default => sub { 1; },
);

=head2 execute

TODOCUMENT

The parameters are checked in Cath::Gemma::Executor

This can ignore the CathGemmaExecSync parameter because this always
performs jobs synchronously anyway.

=cut

sub execute {
	my ( $self, $batches ) = @ARG;

	foreach my $batch ( @{ $batches->batches() } ) {
		my $build_tasks     = $batch->profile_tasks();
		my $scan_tasks      = $batch->scan_tasks();
		my $treebuild_tasks = $batch->treebuild_tasks();
		my @split_build_tasks     = map { @{ $ARG->split_into_singles() } } @$build_tasks;
		my @split_scan_tasks      = map { @{ $ARG->split_into_singles() } } @$scan_tasks;
		my @split_treebuild_tasks = map { @{ $ARG->split_into_singles() } } @$treebuild_tasks;

		$self->exes()->prepare_all();

		# use Carp qw/ confess /;
		# use Data::Dumper;
		# confess Dumper( [ $build_tasks, \@split_build_tasks ] ) . ' ';

		Cath::Gemma::Compute::TaskThreadPooler->run_tasks(
			'profile build',
			$self->max_num_threads(),
			sub {
				my $task = shift;
				$task->execute_task( $self->exes() );
			},
			[ map { [ $ARG ] } @split_build_tasks ]
		);

		Cath::Gemma::Compute::TaskThreadPooler->run_tasks(
			'profile scan',
			$self->max_num_threads(),
			sub {
				my $task = shift;
				$task->execute_task( $self->exes() );
			},
			[ map { [ $ARG ] } @split_scan_tasks ]
		);

		Cath::Gemma::Compute::TaskThreadPooler->run_tasks(
			'tree build',
			$self->max_num_threads(),
			sub {
				my $task = shift;
				$task->execute_task( $self->exes() );
			},
			[ map { [ $ARG ] } @split_treebuild_tasks ]
		);
	}


}

1;