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
# use Thread::Pool::Simple;
use Type::Params        qw/ compile Invocant         /;
use Types::Standard     qw/ ArrayRef CodeRef Int Str /;

=head2 run_tasks

TODOCUMENT

=cut

sub run_tasks {
	state $check = compile( Invocant, Str, Int, CodeRef, ArrayRef[ArrayRef] );
	my ( $proto, $name, $num_threads, $the_code, $data ) = $check->( @ARG );

	my @task_nums = ( 0 .. $#$data );
	my %unfinished_task_nums = map { ( $ARG, 1 ); } @task_nums;

	my $do_task_of_num = sub {
		my $task_num = shift;
		$the_code->( @{ $data->[ $task_num ] } );
		delete $unfinished_task_nums{ $task_num };
	};

	foreach my $task_num ( @task_nums ) {
		$do_task_of_num->( $task_num );
	}

	if ( scalar( keys( %unfinished_task_nums ) ) ) {
		use Data::Dumper;
		confess "Error in executing $name tasks : " . join( ', ', sort( keys( %unfinished_task_nums ) ) )
			. " remain unfinished" . Dumper( [ \@task_nums, \%unfinished_task_nums ] ) . ' ';
	}

}

1;