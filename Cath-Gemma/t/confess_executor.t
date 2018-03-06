#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 2;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Type::Params        qw/ compile        /;

# Non-core (test) (local)
use Test::Exception;

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatchList;
use Cath::Gemma::Executor::ConfessExecutor;
use Cath::Gemma::Types qw/
	CathGemmaExecSync
/;

# Define a function for testing the ConfessExecutor with a specific CathGemmaExecSync
my $test_confess_executor_with_sync_fn = sub {
	state $check = compile( CathGemmaExecSync );
	my ( $exec_sync ) = $check->( @ARG );

	my $batch_list = Cath::Gemma::Compute::WorkBatchList->new();
	my $executor   = Cath::Gemma::Executor::ConfessExecutor->new();

	dies_ok
		sub { $executor->execute_batch_list( $batch_list, $exec_sync ) },
		'Cath::Gemma::Executor::ConfessExecutor should die on call to execute_batch_list() with ExecSync:' . $exec_sync;
};

# Perform a subtest for each CathGemmaExecSync
foreach my $exec_sync ( @{ CathGemmaExecSync->values() } ) {
	subtest
		'ConfessExecutor with ExecSync:' . $exec_sync,
		\&$test_confess_executor_with_sync_fn,
		$exec_sync;
}
