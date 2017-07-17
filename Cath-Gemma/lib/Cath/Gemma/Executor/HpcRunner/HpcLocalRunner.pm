package Cath::Gemma::Executor::HpcRunner::HpcLocalRunner;

=head1 NAME

Cath::Gemma::Executor::HpcRunner::HpcLocalRunner - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Capture::Tiny       qw/ capture        /;
use Log::Log4perl::Tiny qw/ :easy          /;
use Types::Path::Tiny   qw/ Path           /;
use Types::Standard     qw/ Int            /;

with ( 'Cath::Gemma::Executor::HpcRunner' );

=head2 _patch_job_id_and_task_id_into_file_pattern

=cut

sub _patch_job_id_and_task_id_into_file_pattern {
	state $check = compile( Path, Int, Int );
	my ( $file_pattern, $job_id, $task_num ) = $check->( @ARG );

	my $basename = $file_pattern->basename();

	$basename =~ s/\\\$JOB_ID/$job_id/g;
	$basename =~ s/\\\$TASK_ID/$task_num/g;

	return $file_pattern->parent()->child( $basename );
}

=head2 run_job_array

=cut

sub run_job_array {
	my ( $self, $submit_script, $job_name, $stderr_file_pattern, $stdout_file_pattern, $num_batches, $deps ) = @ARG;

	if ( $num_batches < 0 ) {
		confess 'Cannot perform a job with negative number of batches : ' . $num_batches;
	}

	my $fake_job_id = 12345;

	foreach my $task_id ( 0 .. ( $num_batches - 1 ) ) {
		my $task_num = ( $task_id + 1 );
		my $job_stderr_file = _patch_job_id_and_task_id_into_file_pattern( $stderr_file_pattern, $fake_job_id, $task_num );
		my $job_stdout_file = _patch_job_id_and_task_id_into_file_pattern( $stdout_file_pattern, $fake_job_id, $task_num );

		my @run_command = ( "$submit_script" );

		$ENV{ SGE_TASK_ID } = ( $task_num );

		INFO "About to run $job_name, pretending it's $fake_job_id:$task_num (of $num_batches SGE-style tasks)";

		my ( $run_stdout, $run_stderr, $run_exit ) = capture {
			system( @run_command );
		};
		undef $ENV{ SGE_TASK_ID };

		$job_stderr_file->spew( $run_stderr );
		$job_stdout_file->spew( $run_stdout );

		if ( $run_exit != 0 ) {
			WARN 'HpcLocalRunner job finished with non-zero return code ' . $run_exit . ' - see ' . join( ', ', $job_stderr_file, $job_stdout_file );
		}
	}
}

1;