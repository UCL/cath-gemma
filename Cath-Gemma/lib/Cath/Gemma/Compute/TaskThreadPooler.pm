package Cath::Gemma::Compute::TaskThreadPooler;

=head1 NAME

Cath::Gemma::Compute::TaskThreadPooler - TODOCUMENT

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

=head2 run_tasks

TODOCUMENT

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
			warn "\$id : $id, \$task_num : $task_num, \$num_threads : $num_threads";
			$the_code->( @{ $data->[ $task_num ] } );
		},
		[ 0 .. $#$data ]
	);

	# Wait until all tasks are complete
	while ( my ( $index, $value ) = $iter->() ) {}
}

1;