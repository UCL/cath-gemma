#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 12;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Try::Tiny;
use Type::Params        qw/ compile        /;
use Types::Standard     qw/ Bool CodeRef   /;

# Non-core (test) (local)
use Test::Exception;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatchList;

# Cath::Gemma Test
use Cath::Gemma::Test;

use Cath::Gemma::Types qw/
	CathGemmaExecutor
/;

Log::Log4perl->easy_init( {
	level => $WARN,
} );

=head2 check_sub_if_die

TODOCUMENT

=cut

sub check_sub_if_die {
	state $check = compile( CodeRef, Bool );
	my ( $executor, $should_die ) = $check->( @ARG );

	my $died = 0;
	try {
		$executor->();
	}
	catch {
		# If something died and it shouldn't have die, then re-die the problem
		if ( ! $should_die ) {
			die $ARG;
		}

		# Otherwise, check that the problem was that it was confessing due to an attempt to execute
		like( $ARG, qr/Confessing on an attempt to call execute/ );
		$died = 1;
	};

	# If it should have died then check it did
	if ( $should_die ) {
		ok( $died, 'A ConfessExecutor should die when asked to execute something' );
	}
}

=head2 test_build_profile

Test that the specified executor can build a profile

=cut

sub test_build_profile {
	state $check = compile( CathGemmaExecutor, Bool );
	my ( $executor, $should_die ) = $check->( @ARG );

	# Prepare directories for building a profile
	my $aln_dir         = Path::Tiny->tempdir( CLEANUP => 1 );
	my $prof_dir        = Path::Tiny->tempdir( CLEANUP => 1 );
	my $profile_dir_set = Cath::Gemma::Disk::ProfileDirSet->new(
		starting_cluster_dir => test_superfamily_starting_cluster_dir( '1.20.5.200' ),
		aln_dir              => $aln_dir,
		prof_dir             => $prof_dir,
	);

	# Try building a profile, handling whether the executor should confess
	check_sub_if_die(
		sub {
			my $exec_sync = 'always_wait_for_complete';
			$executor->execute_batch(
				Cath::Gemma::Compute::WorkBatch->make_from_profile_build_task_ctor_args(
					dir_set                => $profile_dir_set,
					starting_cluster_lists => [ [ 1, 2 ] ]
				),
				$exec_sync
			);
		},
		$should_die
	);

	# Check that the alignment and profile were built
	if ( ! $should_die ) {
		file_matches(
			$prof_dir                                ->child( 'n0de_c20ad4d76fe97759aa27a0c99bff6710.mk_compass_db.prof' ),
			test_superfamily_aln_dir ( '1.20.5.200' )->child( 'n0de_c20ad4d76fe97759aa27a0c99bff6710.mk_compass_db.prof' ),
			'Built profile file matches expected'
		);
		file_matches(
			$aln_dir                                 ->child( 'n0de_c20ad4d76fe97759aa27a0c99bff6710.faa'                ),
			test_superfamily_prof_dir( '1.20.5.200' )->child( 'n0de_c20ad4d76fe97759aa27a0c99bff6710.faa'                ),
			'Built alignment file matches expected'
		);
	}
}

=head2 test_scan_profile

Test that the specified executor can scan a profile against others

=cut

sub test_scan_profile {
	state $check = compile( CathGemmaExecutor, Bool );
	my ( $executor, $should_die ) = $check->( @ARG );

	# Prepare directories for building a profile
	my $scan_dir      = Path::Tiny->tempdir( CLEANUP => 1 );
	my $gemma_dir_set = Cath::Gemma::Disk::GemmaDirSet->new(
		profile_dir_set => profile_dir_set_of_superfamily( '1.20.5.200' ),
		scan_dir        => $scan_dir,
	);

	# Try building a profile, handling whether the executor should confess
	check_sub_if_die(
		sub {
			my $exec_sync = 'always_wait_for_complete';
			$executor->execute_batch(
				Cath::Gemma::Compute::WorkBatch->make_from_profile_scan_task_ctor_args(
					clust_and_clust_list_pairs => [ [ 1, [ 2, 3 ] ] ],
					dir_set                    => $gemma_dir_set,
				),
				$exec_sync
			);
		},
		$should_die
	);

	# Check that the alignment and profile were built
	if ( ! $should_die ) {
		my $scan_basename = '1.l1st_37693cfc748049e45d87b8c7d8b9aacd.mk_compass_db.scan';
		file_matches(
			$scan_dir                                 ->child( $scan_basename ),
			test_superfamily_scan_dir ( '1.20.5.200' )->child( $scan_basename ),
			'Scan results file matches expected'
		);
	}
}

# Test each of the Executors
foreach my $executor_details (
                            [ 'Cath::Gemma::Executor::ConfessExecutor'      ],
                            [ 'Cath::Gemma::Executor::HpcExecutor', [
                            	submission_dir => Path::Tiny->tempdir( CLEANUP  => 1 ),
                            	hpc_mode => 'hpc_local'
                            ] ],
                            [ 'Cath::Gemma::Executor::LocalExecutor'        ],
                            ) {
	my ( $executor_name, $executor_args ) = @$executor_details;

	subtest 'use_ok for class ' . $executor_name, sub { use_ok( shift ); }, $executor_name;
	subtest 'new_ok for class ' . $executor_name, sub { new_ok( $executor_name => $executor_args ); }, $executor_name;

	my $executor = $executor_name->new( defined( $executor_args ) ? @$executor_args : () );

	subtest
		$executor_name . ' can build a profile correctly',
		\&test_build_profile,
		$executor,
		( ( $executor_name =~ /confess/i ) || 0 );

	subtest
		$executor_name . ' can scan a profile correctly',
		\&test_scan_profile,
		$executor,
		( ( $executor_name =~ /confess/i ) || 0 );

	# subtest
	# 	$executor_name . ' can build a profile correctly',
	# 	\&test_build_profile,
	# 	$executor,
	# 	( ( $executor_name =~ /confess/i ) || 0 );
}