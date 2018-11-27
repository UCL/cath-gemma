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

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                    /;
use Parallel::Iterator  qw/ iterate                  /;
use Type::Params        qw/ compile Invocant         /;
use Types::Standard     qw/ ArrayRef CodeRef Int Str /;

Log::Log4perl->easy_init({
  level  => $DEBUG,
});

=head2 run_tasks

Execute the specified CodeRef for each of the elements in the specified array of data.
Use up to the specified number of threads to parallelise this work.

=cut

sub run_tasks {
	state $check = compile( Invocant, Str, Int, CodeRef, ArrayRef[ArrayRef] );
	my ( $proto, $name, $num_threads, $the_code, $data ) = $check->( @ARG );
	my $iter = iterate(
		{
			workers => $num_threads,
		},
		sub {
			my ( $id, $task_num ) = @ARG;
			$the_code->( @{ $data->[ $task_num ] } );
		},
		[ 0 .. $#$data ]
	);

	my $log_milestone_str;
	$log_milestone_str = Cath::Gemma::Util::get_milestone_string_to_log("$name", "START");
	INFO "$log_milestone_str";
	
	# Wait until all tasks are complete
	while ( my ( $index, $value ) = $iter->() ) {}

	$log_milestone_str = Cath::Gemma::Util::get_milestone_string_to_log("$name", "STOP");
	INFO "$log_milestone_str";
}

1;
