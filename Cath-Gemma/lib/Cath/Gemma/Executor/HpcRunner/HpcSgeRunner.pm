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
use Capture::Tiny       qw/ capture        /;
use Log::Log4perl::Tiny qw/ :easy          /;


with ( 'Cath::Gemma::Executor::HpcRunner' );

=head2 run_job_array

TODOCUMENT

=cut

sub run_job_array {
	my ( $self, $submit_script, $job_name, $stderr_file_pattern, $stdout_file_pattern, $num_batches, $deps, $job_args ) = @ARG;

	if ( $num_batches <= 0 ) {
		confess 'Cannot perform a job with zero/negative number of batches : ' . $num_batches;
	}

	my $submit_host = ( defined( $ENV{SGE_CLUSTER_NAME} ) && $ENV{SGE_CLUSTER_NAME} =~ /leg/i )
	                  ? 'legion.rc.ucl.ac.uk'
	                  : 'bchuckle.cs.ucl.ac.uk';

	my $memy_req                   = '7G';
	# my $time_req                   = '00:30:00'; # 3.40.50.970/n0de_2777281414f5519508e7c439148ccfcb.mk_compass_db.prof takes around 1h15m to build
	# my $time_req                   = '01:30:00'; # 3.40.50.970/n0de_2777281414f5519508e7c439148ccfcb.mk_compass_db.prof takes around 1h15m to build
	my $time_req                   = '06:00:00'; # 3.40.50.970/n0de_2777281414f5519508e7c439148ccfcb.mk_compass_db.prof takes around 1h15m to build
	my $default_resources          = [
		'vf='     . $memy_req,
		'h_vmem=' . $memy_req,
		'h_rt='   . $time_req,
	];
	my %cluster_resources          = (
		'bchuckle.cs.ucl.ac.uk' => [ 'tmem=' . $memy_req, 'hostname=abbott*' ],
		'legion.rc.ucl.ac.uk'   => [                                         ],
	);
	my %cluster_extras             = (
		'bchuckle.cs.ucl.ac.uk' => [ '-P', 'cath' ], # Can be removed in the future - is currently being used as part of Tristan giving us dedicated access to a pool of nodes
		'legion.rc.ucl.ac.uk'   => [              ],
	);

	my $cluster_specific_resources = $cluster_resources{ $submit_host }
		or confess 'Submit host ' . $submit_host . ' unrecognised';

	my $cluster_specific_extras    = $cluster_extras{ $submit_host }
		or confess 'Submit host ' . $submit_host . ' unrecognised';

	# TODO: Consider adding a parameter that allows users to specify the location of the
	#       Perl to run the jobs with and then prepend it to the PATH here
	my @qsub_command = (
		'ssh', $submit_host,
		'qsub',
		'-l', join( ',', @$default_resources, @$cluster_specific_resources ),
		'-N', $job_name,
		'-e', $stderr_file_pattern,
		'-o', $stdout_file_pattern,
		'-v', 'PATH=' . $ENV{ PATH }, # Ensure that the job will pick up the same Perl that's being used to run this (relevant on the CS cluster)
		                              # Can't just use -v PATH because the qsub is being run through ssh so may be run with a significantly different PATH
		'-S', '/bin/bash',
		'-t', '1-' . $num_batches,
		(
			scalar( @$deps )
			? ( '-hold_jid', join( ',', @$deps ) )
			: (                                  )
		),
		@$cluster_specific_extras,
		"$submit_script",
		@$job_args,
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