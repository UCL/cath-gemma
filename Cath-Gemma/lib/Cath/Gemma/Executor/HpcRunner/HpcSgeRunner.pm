package Cath::Gemma::Executor::HpcRunner::HpcSgeRunner;

=head1 NAME

Cath::Gemma::Executor::HpcRunner::HpcSgeRunner - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;

with ( 'Cath::Gemma::Executor::HpcRunner' );

=head2 run_job_array

=cut

sub run_job_array {
	my ( $self, $submit_script, $job_name, $stderr_file_pattern, $stdout_file_pattern, $num_batches ) = @ARG;

	if ( $num_batches <= 0 ) {
		confess 'Cannot perform a job with zero/negative number of batches : ' . $num_batches;
	}

	my $submit_host = ( defined( $ENV{SGE_CLUSTER_NAME} ) && $ENV{SGE_CLUSTER_NAME} =~ /leg/i )
	                  ? 'legion.rc.ucl.ac.uk'
	                  : 'bchuckle.cs.ucl.ac.uk';

	my @qsub_command = (
		'ssh', $submit_host,
		'qsub',
		'-l', 'vf=1G,h_vmem=1G,h_rt=00:30:00',
		'-N', $job_name,
		'-e', $stderr_file_pattern,
		'-o', $stdout_file_pattern,
		'-v', 'PATH', # Ensure that the PATH is passed through to the job (so that, in particular, it picks up the right Perl)
		#'-v', 'PATH=/share/apps/perl/bin:$PATH', # Ensure that the shared Perl is used on the CS cluster (with login node "bchuckle")
		'-S', '/bin/bash',
		'-t', '1-'.$num_batches,
		"$submit_script",
		# -hold_jid
		# -hold_jid_ad
	);

	my ( $qsub_stdout, $qsub_stderr, $qsub_exit ) = capture {
		system( @qsub_command );
	};

	my $job_id;
	if ( $qsub_stdout =~ /Your job-array (\d+)\.\d+\-\d+:\d+.* has been submitted/ ) {
		$job_id = $1;
	}
	else {
		use Carp qw/ confess /;
		use Data::Dumper;
		confess Dumper( [ \@qsub_command, $qsub_stdout, $qsub_stderr, $qsub_exit ] );
	}
	INFO "Submitted compute-cluster job $job_id with $num_batches batches";

	return $job_id;
}

1;