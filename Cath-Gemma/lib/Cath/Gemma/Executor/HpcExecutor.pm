package Cath::Gemma::Executor::HpcExecutor;

=head1 NAME

Cath::Gemma::Executor::HpcExecutor - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use Switch;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Types::Path::Tiny   qw/ Path           /;

# Cath
use Cath::Gemma::Executor::HpcRunner::HpcLocalRunner;
use Cath::Gemma::Executor::HpcRunner::HpcSgeRunner;
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatcher
	CathGemmaExecutorHpcRunner
	CathGemmaHpcMode
	/;
use Cath::Gemma::Util;

with ( 'Cath::Gemma::Executor' );

=head2 submission_dir

=cut

has submission_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 hpc_mode

=cut

has hpc_mode => (
	is       => 'ro',
	isa      => CathGemmaHpcMode,
	required => 1,
	default  => sub {
		my $running_on_sge = guess_if_running_on_sge();
		if ( $running_on_sge ) {
			INFO __PACKAGE__ . ' has deduced this is genuinely running on SGE and will use qsub';
		}
		else {
			INFO __PACKAGE__ . ' has deduced this is not actually running on SGE and so will construct HPC job scripts and then run them itself';
		}
		( $running_on_sge ? 'hpc_sge' : 'hpc_local' );
	}
);

=head2 _runner

=cut

has _runner => (
	is       => 'lazy',
	isa      => CathGemmaExecutorHpcRunner,
);

=head2 _work_batcher

=cut

has _work_batcher => (
	is      => 'ro',
	isa     => CathGemmaComputeWorkBatcher,
	default => sub { Cath::Gemma::Compute::WorkBatcher->new(); }
);

=head2

=cut

sub _build__runner {
	my $self = shift;
	my $val = $self->hpc_mode();
	switch ( $val ) {
		case 'hpc_local' { return Cath::Gemma::Executor::HpcRunner::HpcLocalRunner->new(); }
		case 'hpc_sge'   { return Cath::Gemma::Executor::HpcRunner::HpcSgeRunner  ->new(); }
	}
	confess 'Could not recognise CathGemmaHpcMode value ' . $self->hpc_mode();
}

=head2 execute

=cut

sub execute {
	my ( $self, $batches ) = @ARG;


	$batches = $self->_work_batcher()->rebatch( $batches );

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

	my $grouped_dependencies = $batches->get_grouped_dependencies();
	foreach my $dependencies_group ( @$grouped_dependencies ) {
		my ( $batch_indices, $dependencies ) = @$dependencies_group;

		my $group_batches = [ @{ $batches->batches() }[ @$batch_indices ] ];

		# use Carp qw/ confess /;
		# use Data::Dumper;
		# warn Dumper( [ $batch_indices ] );

		my $id      = $batches->id_of_batch_indices( $batch_indices );

		my @batch_files;
		foreach my $batch ( @$group_batches ) {
			my $batch_freeze_file = $job_dir->child( $id . '.' . 'batch_' . $batch->id() . '.freeze' );
			$batch->write_to_file( $batch_freeze_file );
			push @batch_files, "$batch_freeze_file";
		}

		my $batch_files_file = $job_dir->child( $id . '.' . 'job_batch_files' );
		$batch_files_file->spew( join( "\n", @batch_files ) . "\n" );

		# TODO: Move this hard-coded script name elsewhere
		my $execute_batch_script = path( "$FindBin::Bin" )->child( 'execute_work_batch.pl' ) . "";

		my $num_batches = scalar( @$group_batches );

		my $submit_script = $job_dir->child( $id . '.' . 'job_script.bash' );
		$submit_script->spew( <<"EOF" );
#!/bin/bash -l

# Where a compute-cluster provides a more recent perl through the module system, this will pick it up
( ( module avail perl ) 2>&1 | grep -q perl ) && module load perl

BATCH_FILES_FILE=$batch_files_file
echo HOSTNAME         : \$HOSTNAME
echo BATCH_FILES_FILE : \$BATCH_FILES_FILE
echo SGE_TASK_ID      : \$SGE_TASK_ID

BATCH_FILE=\$(awk "NR==\$SGE_TASK_ID" \$BATCH_FILES_FILE)
echo BATCH_FILE       : \$BATCH_FILE

$execute_batch_script \$BATCH_FILE

EOF

		$submit_script->chmod( 'a+x' )
			or confess "Unable to chmod submit script \"$submit_script\" to be executable : $OS_ERROR";

		my $job_name            = 'CathGemma.'.$id;
		my $stderr_file_stem    = $job_dir->child( $id );
		my $stdout_file_stem    = $job_dir->child( $id );
		my $stderr_file_suffix  = '.stderr';
		my $stdout_file_suffix  = '.stdout';
		my $stderr_file_pattern = $stderr_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stderr_file_suffix;
		my $stdout_file_pattern = $stdout_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stdout_file_suffix;

		push @job_dependencies, $self->_runner()->run_job_array(
			$submit_script,
			$job_name,
			$stderr_file_pattern,
			$stdout_file_pattern,
			$num_batches,
			[ @job_dependencies[ @$dependencies ] ],
		);
	}
}


1;