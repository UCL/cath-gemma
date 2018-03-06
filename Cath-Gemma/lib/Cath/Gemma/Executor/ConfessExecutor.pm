package Cath::Gemma::Executor::ConfessExecutor;

=head1 NAME

Cath::Gemma::Executor::ConfessExecutor - An Executor that just confesses on any attempt to execute_batch_list()

This can be useful in testing/profiling for:
 * checking that no executions are attempted or
 * stopping a run at the first attempted execution.

=cut

use strict;
use warnings;

# Core
use Carp qw/ confess /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

with ( 'Cath::Gemma::Executor' );

=head2 execute_batch_list

Do what ConfessExecutor says on the tin: confess

The parameters are checked in Cath::Gemma::Executor

=cut

sub execute_batch_list {
	confess 'Confessing on an attempt to call execute_batch_list() on a ConfessExecutor';
}

1;