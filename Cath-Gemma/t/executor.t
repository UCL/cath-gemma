use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Test
use Test::Exception;
use Test::More tests => 2;

# Cath
use Cath::Gemma::Compute::WorkBatchList;
use Cath::Gemma::Executor::ConfessExecutor;
use Cath::Gemma::Types qw/
	CathGemmaExecSync
/;

# ConfessExecutor
{
	my $batch_list = Cath::Gemma::Compute::WorkBatchList->new();
	my $executor   = Cath::Gemma::Executor::ConfessExecutor->new();

	foreach my $exec_sync ( @{ CathGemmaExecSync->values() } ) {
		dies_ok
			{ $executor->execute( $batch_list, $exec_sync ) }
			( 'Cath::Gemma::Executor::ConfessExecutor should die on call to execute() with ExecSync:' . $exec_sync );
	}
}
