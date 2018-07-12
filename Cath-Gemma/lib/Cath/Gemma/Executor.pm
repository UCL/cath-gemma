package Cath::Gemma::Executor;

=head1 NAME

Cath::Gemma::Executor - Execute a Cath::Gemma::Compute::WorkBatchList of batches in some way

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars  /;
use v5.10;

# Moo
use Moo::Role;
use strictures 2;

# Non-core (local)
use Type::Params      qw/ compile         /;
use Types::Standard   qw/ ArrayRef Object /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatch
	CathGemmaComputeWorkBatchList
	CathGemmaExecSync
/;

=head2 requires execute_batch_list

Require that consumers of the Executor role must provide a execute_batch_list()

=cut

requires 'execute_batch_list';

=head2 before execute_batch_list

execute_batch_list() executes the specified WorkBatchList using the specified ExecSync

This code shares the type checks on the input parameters before the concrete Executor's
execute_batch_list()

=cut

before execute_batch_list => sub {
	state $check = compile( Object, CathGemmaComputeWorkBatchList, CathGemmaExecSync );

	$check->( @ARG );
};

=head2 execute_batch

Convenience function to execute a WorkBatch

This just bundles the WorkBatch up in a WorkBatchList and passes it to execute_batch_list().

=cut

sub execute_batch {
	state $check = compile( Object, CathGemmaComputeWorkBatch, CathGemmaExecSync );
	my ( $self, $work_batch, $exec_sync ) = $check->( @ARG );

	$self->execute_batch_list(
		Cath::Gemma::Compute::WorkBatchList->new( batches => [ $work_batch ] ),
		$exec_sync
	);
}

1;