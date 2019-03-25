package Cath::Gemma::Executor::SpawnHpcSgeRunner;

=head1 NAME

Cath::Gemma::Executor::SpawnHpcSgeRunner - Submit a real HPC job to run the HPC script

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use Data::Dumper;
use English             qw/ -no_match_vars /;
use List::Util          qw/ any max min    /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Capture::Tiny       qw/ capture        /;
use Log::Log4perl::Tiny qw/ :easy          /;

# Cath::Gemma
use Cath::Gemma::Util;

=head1 ROLES

=over

=item L<Cath::Gemma::Executor::SpawnRunner>

=item L<Cath::Gemma::Executor::HasGemmaClusterName>

=back

=cut

with ( 'Cath::Gemma::Executor::SpawnRunner' );
with ( 'Cath::Gemma::Executor::HasGemmaClusterName' );

=head2 run_job_array

TODOCUMENT

=cut

sub run_job_array {
	my ( $self, $submit_script, $job_name, $stderr_file_pattern, $stdout_file_pattern, $num_batches, $deps, $job_args, $max_est_time , $ssh_to_login_node) = @ARG;
	#default is to ssh to login node for qsub
	$ssh_to_login_node //= 1;

	if ( $num_batches <= 0 ) {
		confess 'Cannot perform a job with zero/negative number of batches : ' . $num_batches;
	}

	my $cluster_name = $self->get_cluster_name;
	my $submit_host = $self->get_cluster_submit_host;

	my $memy_req = '15G';
	if ( exists $ENV{GEMMA_CLUSTER_MEM} && $ENV{GEMMA_CLUSTER_MEM} ) {
		INFO "Overriding the default memory requirement ($memy_req) with a custom value from \$GEMMA_CLUSTER_MEM=$ENV{GEMMA_CLUSTER_MEM}";
		$memy_req = $ENV{GEMMA_CLUSTER_MEM};
	}

	# Clamp time between 6 hours and 72 hours
	# (legion rejects jobs longer than 72 hours with:
	#  `Unable to run job: Rejected by policyjsv Reason:Unable to find a policy compliant place to run job`)
	my $duration_in_seconds        = min(
		max(
			$max_est_time + $max_est_time + $max_est_time + $max_est_time,
			Time::Seconds->new( 21600 ) # 6 hours in seconds
		),
		Time::Seconds->new( 259200 ) # 72 hours in seconds
	);
	my $time_req                   = time_seconds_to_sge_string( $duration_in_seconds );
	my $default_resources          = [
		'vf='     . $memy_req,
		'h_vmem=' . $memy_req,
		'h_rt='   . $time_req,
	];
	my %cluster_resources          = (
		# 'bchuckle.cs.ucl.ac.uk' => [ 'tmem=' . $memy_req, 'hostname=abbott*' ], # Can be removed in the future - is currently being used as part of Tristan giving us dedicated access to a pool of nodes
		'bchuckle.cs.ucl.ac.uk' => [ 'tmem=' . $memy_req                     ],
		'legion.rc.ucl.ac.uk'   => [                                         ],
		'myriad.rc.ucl.ac.uk'   => [                                         ],
	);
	my %cluster_extras             = (
		#'bchuckle.cs.ucl.ac.uk' => [ '-P', 'cath' ], # Can be removed in the future - is currently being used as part of Tristan giving us dedicated access to a pool of nodes
		'bchuckle.cs.ucl.ac.uk' => [              ],
		'legion.rc.ucl.ac.uk'   => [              ],
		'myriad.rc.ucl.ac.uk'   => [              ],
	);

	my $cluster_specific_resources = $cluster_resources{ $submit_host }
		or confess 'Submit host ' . $submit_host . ' unrecognised';

	my $cluster_specific_extras    = $cluster_extras{ $submit_host }
		or confess 'Submit host ' . $submit_host . ' unrecognised';

	# # This block, mostly written by Ian, was useful in debugging a problem with submitting jobs
	# # It turned out the problem was that it was intermittently running out of memory
	# if ( 0 ) {
	#
	# 	my ( $pretest_stdout, $pretest_stderr, $pretest_exit ) = capture {
	# 		open( IN, "ssh -v bchuckle.cs.ucl.ac.uk echo hello |") || die "! Error: failed to open: $!";
	# 		while( my $line = <IN> ) {
	# 			print "LINE: $line\n";
	# 		}
	# 		system( 'ssh', '-v', 'bchuckle.cs.ucl.ac.uk', 'echo', 'hello' );
	# 	};
	#
	# 	confess Dumper( {
	# 		'$!'     => $!,
	# 		exit     => $pretest_exit,
	# 		PATH     => $ENV{PATH},
	# 		PERL5LIB => $ENV{PERL5LIB},
	# 		stderr   => $pretest_stderr,
	# 		stdout   => $pretest_stdout,
	# 	});
	# }

	# pass GEMMA_* environment variables through to child jobs

	my @gemma_env_args = map { ('-v', "$_='$ENV{$_}'") } # map to '-v key=value'
		grep { $ENV{$_} }                                # only env keys that have trueish values
		grep { /^GEMMA/ }                                # only GEMMA env keys
		keys %ENV;

	# TODO: Consider adding a parameter that allows users to specify the location of the
	#       Perl to run the jobs with and then prepend it to the PATH here
	my @qsub_command = (
		($ssh_to_login_node ? ('ssh', $submit_host) : ()),
		# 'ssh', '-v', $submit_host,
		'qsub',
		'-l', join( ',', @$default_resources, @$cluster_specific_resources ),
		'-N', $job_name,
		'-e', $stderr_file_pattern,
		'-o', $stdout_file_pattern,
		# Ensure that the job will pick up the same Perl that's being used to run this (relevant on the CS cluster)
		# Can't just use -v PATH because the qsub is being run through ssh so may be run with a significantly different PATH
		'-v', 'PATH=' . $ENV{ PATH }, 
		'-S', '/bin/bash',
		'-t', '1-' . $num_batches,
		(
			scalar( @$deps )
			? ( '-hold_jid', join( ',', @$deps ) )
			: (                                  )
		),
		@gemma_env_args,
		@$cluster_specific_extras,
		"$submit_script",
		@$job_args,
	);

	DEBUG( "Executing qsub command: " . join( " ", @qsub_command ) );

	my ( $qsub_stdout, $qsub_stderr, $qsub_exit ) = capture {
		system( @qsub_command );
	};


	my $job_id;
	if ( $qsub_stdout =~ /Your job-array (\d+)\.\d+\-\d+:\d+.*? has been submitted/ ) {
		$job_id = $1;
	}
	else {
		use Carp qw/ confess /;
		use Data::Dumper;
		confess Dumper( {
			command_arr => \@qsub_command,
			command_str => join( ' ', @qsub_command ),
			exit        => $qsub_exit,
			stderr      => $qsub_stderr,
			stdout      => $qsub_stdout,
		} );
	}
	INFO "Submitted compute-cluster job $job_id with $num_batches batches (requested : $time_req time; $memy_req memory)";

	return $job_id;
}

=head2 wait_for_jobs

This will wait for all active jobs to finish (using C<ssh qstat> to check status every 60 seconds)

=cut

sub wait_for_jobs {
	my ( $self, $jobs ) = @ARG;

	my @wanted_jobs = sort { $a <=> $b } grep { defined( $ARG ); } @$jobs;
	my %wanted_jobs = map { ( $ARG, 1 ); } @wanted_jobs;

	# this will die if GEMMA_CLUSTER_NAME is not set
	my $submit_host = $self->get_cluster_submit_host;

	while ( 1 ) {
		my $wait_in_seconds = Time::Seconds->new( 60 );
		DEBUG "Waiting $wait_in_seconds seconds before (re)checking for submitted jobs : ". join( ', ', @wanted_jobs );
		sleep $wait_in_seconds->seconds();

		DEBUG "Submit host is : " . $submit_host;

		my @qstat_command = (
			'ssh', $submit_host,
			'qstat',
		);
		DEBUG "qstat command is : " . join( ' ', @qstat_command );

		# DEBUG "About to run command " . join( ' ', @qstat_command );
		my ( $qstat_stdout, $qstat_stderr, $qstat_exit ) = capture {
			system( @qstat_command );
		};
		# DEBUG "Finished running command " . join( ' ', @qstat_command );
		# warn localtime() . ' : \$qstat_stdout : ' . $qstat_stdout;
		# warn localtime() . ' : \$qstat_exit   : ' . $qstat_exit;
		# warn localtime() . ' : \$qstat_stderr : ' . $qstat_stderr;

		# DEBUG 'Dumper is ' . Dumper( {
		# 	command_arr => \@qstat_command,
		# 	command_str => join( ' ', @qstat_command ),
		# 	exit        => $qstat_exit,
		# 	stderr      => $qstat_stderr,
		# 	stdout      => $qstat_stdout,
		# } );

		if ( $qstat_exit != 0 ) {
			WARN "qstat returned non-zero status:\n". Dumper( {
				command_arr => \@qstat_command,
				command_str => join( ' ', @qstat_command ),
				exit        => $qstat_exit,
				stderr      => $qstat_stderr,
				stdout      => $qstat_stdout,
			} );
		}

		my @stdout_lines   = split( /\n/, $qstat_stdout );
		my @active_job_ids = map { $ARG =~ /^\s*(\d+)\s/; $1; } grep { $ARG =~ /^\s*\d+\s/ } @stdout_lines;

		my $any_running_jobs_wanted = any { $wanted_jobs{ $ARG } } @active_job_ids;
		DEBUG sprintf( "Found active running jobs are : %s (there are %d wanted jobs; any_running_jobs_wanted is: %s)",
				join( ', ', @active_job_ids ),
				scalar( @wanted_jobs ),
				$any_running_jobs_wanted ? 'TRUE' : 'FALSE',
			);
			
		if ( ! $any_running_jobs_wanted ) {
			warn localtime() . ' : Jobs complete - will now return';
			return;
		}
	}
}

1;
