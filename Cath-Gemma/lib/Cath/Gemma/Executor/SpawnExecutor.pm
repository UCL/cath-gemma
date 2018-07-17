package Cath::Gemma::Executor::SpawnExecutor;

=head1 NAME

Cath::Gemma::Executor::SpawnExecutor - Execute a Cath::Gemma::Compute::WorkBatchList by spawning another Perl process via a shell script

Depending on the SpawnRunner, the spawning may involve executing the batch script locally or submitting it to an SGE cluster

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use FindBin;
use Switch;
use List::Util          qw/ max            /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Types::Path::Tiny   qw/ Path           /;

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatcher;
use Cath::Gemma::Executor::SpawnHpcSgeRunner;
use Cath::Gemma::Executor::SpawnLocalRunner;
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatcher
	CathGemmaExecutorSpawnRunner
	CathGemmaSpawnMode
	/;
use Cath::Gemma::Util;

=head1 ROLES

=over

=item L<Cath::Gemma::Executor::SpawnRunner>

=item L<Cath::Gemma::Executor::HasGemmaClusterName>

=back

=cut

with ( 'Cath::Gemma::Executor' );
with ( 'Cath::Gemma::Executor::HasGemmaClusterName' );

=head1 ATTRIBUTES

=head2 submission_dir

TODOCUMENT

=cut

has submission_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 hpc_mode

TODOCUMENT

=cut

has hpc_mode => (
	is       => 'ro',
	isa      => CathGemmaSpawnMode,
	required => 1,
	default  => sub {
		my $running_on_sge = guess_if_running_on_sge();
		if ( $running_on_sge ) {
			INFO __PACKAGE__ . ' has deduced this is genuinely running in an SGE environment and so will submit job scripts via qsub';
		}
		else {
			INFO __PACKAGE__ . ' has deduced this isn\'t running in an SGE environment and so will run job scripts itself';
		}
		( $running_on_sge ? 'spawn_hpc_sge' : 'spawn_local' );
	}
);

=head2 _runner

TODOCUMENT

=cut

has _runner => (
	is       => 'lazy',
	isa      => CathGemmaExecutorSpawnRunner,
);

=head2 _work_batcher

TODOCUMENT

=cut

has _work_batcher => (
	is      => 'ro',
	isa     => CathGemmaComputeWorkBatcher,
	default => sub { Cath::Gemma::Compute::WorkBatcher->new(); }
);

=head2

TODOCUMENT

=cut

sub _build__runner {
	my $self = shift;
	my $val = $self->hpc_mode();
	switch ( $val ) {
		case 'spawn_hpc_sge' { return Cath::Gemma::Executor::SpawnHpcSgeRunner->new(); }
		case 'spawn_local'   { return Cath::Gemma::Executor::SpawnLocalRunner ->new(); }
	}
	confess 'Could not recognise CathGemmaSpawnMode value ' . $self->hpc_mode();
}

=head2 execute_batch_list

TODOCUMENT

=cut

sub execute_batch_list {
	my ( $self, $batches, $exec_sync ) = @ARG;

	# use Carp qw/ cluck /;
	# cluck "\n\n\n****** In SpawnExecutor::execute_batch_list";

	my $submit_script = path( "$FindBin::Bin/../script/sge_submit_script.bash" )->realpath;

	my $cluster_name = $self->get_cluster_name( assume_local_if_not_set => 1 );

	warn "WARNING: TEMPORARILY NOT REBATCHING";
	# $batches = $self->_work_batcher()->rebatch( $batches );

	# use Carp qw/ confess /;
	# use Data::Dumper;
	# confess Dumper([
	# 	$batches->num_batches(),
	# 	$batches->dependencies(),
	# ]);

	my $job_dir = $self->submission_dir()->realpath();

	if ( ! -d $job_dir ) {
		$job_dir->mkpath()
			or confess "Unable to make compute cluster submit directory \"$job_dir\" : $OS_ERROR";
	}

	my @job_dependencies;

	# warn "****** In SpawnExecutor::execute_batch_list(), about to loop over deps for batches numbering " . $batches->num_batches();
	my $grouped_dependencies = $batches->get_grouped_dependencies();

	# use Data::Dumper;
	# warn Dumper( $grouped_dependencies );

	foreach my $dependencies_group ( @$grouped_dependencies ) {
		my ( $batch_indices, $dependencies ) = @$dependencies_group;
		# warn "****** In SpawnExecutor::execute_batch_list(), in loop over deps";

		my $group_batches          = [ @{ $batches->batches() }[ @$batch_indices ] ];

		# TODONOW Consider moving this to Executor::execute_batch_list() and have that just return if nothing to do
		# Then can remove those checks from TreeBuilder and WindowedTreeBuilder
		my $max_est_batch_exe_time = Time::Seconds->new( max( map { $ARG->estimate_time_to_execute(); } @$group_batches ) );
		if ( $max_est_batch_exe_time == Time::Seconds->new( 0 ) ) {
			WARN 'In Cath::Gemma::Executor::SpawnExecutor::execute_batch_list(), asked to execute job with estimated execution time of 0s - perhaps client code is unknowingly attempting to do work that has already been done';
		}

		my $id                     = $batches->id_of_batch_indices( $batch_indices );

		my @batch_files;
		foreach my $batch ( @$group_batches ) {
			my $batch_freeze_file = $job_dir->child( $id . '.' . 'batch_' . $batch->id() . '.freeze' );
			$batch->write_to_file( $batch_freeze_file );
			push @batch_files, "$batch_freeze_file";
		}

		# warn "****** In SpawnExecutor::execute_batch_list(), considered freeze files";

		my $batch_files_file = $job_dir->child( $id . '.' . 'job_batch_files' );
		$batch_files_file->spew( join( "\n", @batch_files ) . "\n" );

		# TODO: Move this hard-coded script name elsewhere
		my $execute_batch_script = path( "$FindBin::Bin" )->parent()->child( 'script' )->child( 'execute_work_batch.pl' )->realpath() . "";

		my $num_batches = scalar( @$group_batches );

		my $job_name            = 'CathGemma.'.$id;
		my $stderr_file_stem    = $job_dir->child( $id );
		my $stdout_file_stem    = $job_dir->child( $id );
		my $stderr_file_suffix  = '.stderr';
		my $stdout_file_suffix  = '.stdout';
		my $stderr_file_pattern = $stderr_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stderr_file_suffix;
		my $stdout_file_pattern = $stdout_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stdout_file_suffix;

		push @job_dependencies, $self->_runner()->run_job_array(
			path( "$FindBin::Bin/../script/sge_submit_script.bash" )->realpath(),
			$job_name,
			$stderr_file_pattern,
			$stdout_file_pattern,
			$num_batches,
			[ @job_dependencies[ @$dependencies ] ],
			[ "$execute_batch_script", "$batch_files_file", "$cluster_name" ],
			$max_est_batch_exe_time,
		);
	}

	if ( $exec_sync eq 'always_wait_for_complete' ) {
		$self->_runner()->wait_for_jobs( \@job_dependencies );
	}
}

1;
