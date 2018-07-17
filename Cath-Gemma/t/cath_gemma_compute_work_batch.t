#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English qw/ -no_match_vars /;
use FindBin;
use Storable qw/ freeze thaw /;

# Core (test)
use Test::More tests => 2;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use JSON::MaybeXS;
use Path::Tiny;

# my $bootstrap_tests = $ENV{ BOOTSTRAP_TESTS } // 0;
# my $test_basename   = path( $PROGRAM_NAME )->basename( '.t' );
my $data_dir        = path( 'data' );

BEGIN{ use_ok( 'Cath::Gemma::Compute::WorkBatch' ) }

subtest 'batches_have_distinct_ids' => sub {
	my $dir_set = Cath::Gemma::Disk::ProfileDirSet->new(
		base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
			base_dir => path( '/tmp' ),
			project  => '1.10.8.10',
		)
	);
	my $batch_a_b = Cath::Gemma::Compute::WorkBatch->new(
		profile_tasks => [ Cath::Gemma::Compute::Task::ProfileBuildTask->new(
			starting_cluster_lists => [ [ qw/ cluster_a cluster_b / ] ],
			dir_set                => $dir_set,
		) ],
	);

	my $batch_c = Cath::Gemma::Compute::WorkBatch->new(
		profile_tasks => [ Cath::Gemma::Compute::Task::ProfileBuildTask->new(
			starting_cluster_lists => [ [ qw/ cluster_c / ] ],
			dir_set                => $dir_set,
		) ],
	);

	ok(   Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_a_b           ] ) );
	ok(   Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_c             ] ) );
	ok(   Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_a_b, $batch_c ] ) );

	ok( ! Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_a_b, $batch_c, $batch_a_b ] ) );
	ok( ! Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_a_b, $batch_c, $batch_c   ] ) );
}
