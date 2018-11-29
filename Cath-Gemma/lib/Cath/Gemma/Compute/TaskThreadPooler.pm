package Cath::Gemma::Compute::TaskThreadPooler;

=head1 NAME

Cath::Gemma::Compute::TaskThreadPooler - Execute code over an array, potentially using multiple threads

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                  /;
use English             qw/ -no_match_vars           /;
use v5.10;
use Scalar::Util        qw/ blessed /;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                    /;
use Parallel::Iterator  qw/ iterate                  /;
use Type::Params        qw/ compile Invocant         /;
use Types::Standard     qw/ ArrayRef HashRef InstanceOf CodeRef Int Str /;
use JSON::MaybeXS;

use Cath::Gemma::Types qw/
	CathGemmaComputeTaskProfileScanTask
	CathGemmaComputeTaskProfileBuildTask
	CathGemmaComputeTaskBuildTreeTask
	is_CathGemmaComputeTaskProfileScanTask
	is_CathGemmaComputeTaskProfileBuildTask
	is_CathGemmaComputeTaskBuildTreeTask
/;

use Cath::Gemma::Util;

my $JSON = JSON::MaybeXS->new( utf8 => 1, pretty => 0, canonical => 1 );

Log::Log4perl->easy_init({
  level  => $DEBUG,
});

=head2 run_tasks

Execute the specified CodeRef for each of the elements in the specified array of data.
Use up to the specified number of threads to parallelise this work.

=cut

my $TASK_COUNTER = 1;
sub run_tasks {
	state $check = compile( Invocant, Str, Int, CodeRef, ArrayRef[ArrayRef] );
	my ( $proto, $name, $num_threads, $the_code, $data ) = $check->( @ARG );

	my $task_count = scalar( @$data );

	my $iter = iterate(
		{
			workers => $num_threads,
		},
		sub {
			my ( $id, $task_num ) = @ARG;
			my $task_data = $data->[ $task_num ];
			my $task_result = $the_code->( @{ $task_data } );
			return [$task_data, $task_result];
		},
		[ 0 .. $#$data ]
	);

	return if $task_count == 0;

	if ( $task_count > 0 ) {
		INFO Cath::Gemma::Util::get_milestone_log_string( $name, "START" );
	}
	
	# Wait until all tasks are complete
	while ( my ( $index, $task_io ) = $iter->() ) {
		
		my $task        = $task_io->[0]->[0];
		my $task_result = $task_io->[1]->[0];

		my $task_info = _get_task_meta( $task, $task_result );

		# log stuff for each task
		INFO sprintf( "%s [%d] %s",
			Cath::Gemma::Util::get_milestone_log_string( $name, "TASK" ),
			$TASK_COUNTER++,
			$task_info,
		);
	}

	if ( $task_count > 0 ) {
		INFO Cath::Gemma::Util::get_milestone_log_string( $name, "END" );
	}
}

sub _get_task_meta {
	state $check = compile( InstanceOf[
			CathGemmaComputeTaskProfileScanTask,
			CathGemmaComputeTaskProfileBuildTask,
			CathGemmaComputeTaskBuildTreeTask,
		], HashRef);
	my ( $task, $task_result ) = $check->( @ARG );

	my %task_meta;

	# both return the results from Util::build_alignment_and_profile
	if ( is_CathGemmaComputeTaskProfileBuildTask($task) or 
		 is_CathGemmaComputeTaskBuildTreeTask($task) ) 
	{
		my $id = $task_result->{aln_filename}->basename( alignment_suffix() );

		%task_meta = (
			id       => $id,
			duration => 0 + ($task_result->{duration} ? $task_result->{duration}->seconds : 0),
			cached   => $task_result->{aln_file_already_present} ? 1 : 0,
		);

		if ( exists $task_result->{gap_percentage} ) {
			$task_meta{ gap_per  } = sprintf( "%.1f", $task_result->{gap_percentage} );
		}
		if ( exists $task_result->{num_sequences} ) {
			$task_meta{ seqs     } = 0 + $task_result->{num_sequences};
		}
		if ( $task->can('total_num_starting_clusters')) {
			$task_meta{ clusters } = 0 + $task->total_num_starting_clusters;
		}
	}
	elsif ( is_CathGemmaComputeTaskProfileScanTask($task) ) {
		%task_meta = (
			duration => 0 + ($task_result->{duration} ? $task_result->{duration}->seconds : 0),
		);
	}

	my $task_info = %task_meta ? $JSON->encode( \%task_meta ) : '';

	return $task_info;
}

1;
