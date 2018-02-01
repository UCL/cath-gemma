#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More tests => 9;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /; # ********** TEMPORARY **********
use Path::Tiny;
use Try::Tiny;
use Type::Params        qw/ compile        /;
use Types::Standard     qw/ Bool           /;

# Non-core (test) (local)
use Test::Exception;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatchList;

# Cath::Gemma Test
use Cath::Gemma::Test;

# use Cath::Gemma::Executor::ConfessExecutor;
use Cath::Gemma::Types qw/
	CathGemmaExecutor
/;

Log::Log4perl->easy_init( {
	level => $WARN,
} );

my $aln_dir         = Path::Tiny->tempdir( CLEANUP => 1 );
my $prof_dir        = Path::Tiny->tempdir( CLEANUP => 1 );
my $profile_dir_set = Cath::Gemma::Disk::ProfileDirSet->new(
	starting_cluster_dir => test_superfamily_starting_cluster_dir( '3.30.70.1470' ),
	aln_dir              => $aln_dir,
	prof_dir             => $prof_dir,
);

sub test_executor {
	# use Carp qw/ cluck /;
	# cluck localtime() . ' : Starting test_executor...';
	state $check = compile( CathGemmaExecutor, Bool );
	my ( $executor, $should_confess ) = $check->( @ARG );

	# use Carp qw/ confess /;
	# use Data::Dumper;
	# warn 'here with ' . Dumper( $executor );

	my $exec_sync = 'always_wait_for_complete';
	my $confessed = 0;
	try {
		# warn localtime() . ' : About to...';
		$executor->execute_batch(
			Cath::Gemma::Compute::WorkBatch->make_from_profile_build_task_ctor_args(
				dir_set                => $profile_dir_set,
				starting_cluster_lists => [ [ 8, 9, 24 ], [ 25, 26, 30 ], [ 31, 33, 44 ] ]
			),
			# Cath::Gemma::Compute::WorkBatch->new(
			# 	profile_tasks => [ Cath::Gemma::Compute::Task::ProfileBuildTask->new(
			# 		starting_cluster_lists => [ [ 8, 9, 24 ], [ 25, 26, 30 ], [ 31, 33, 44 ] ]
			# 	) ]
			# ),
			$exec_sync
		);
	}
	catch {
		# use Carp qw/ confess /;
		# use Data::Dumper;

		if ( ! $should_confess ) {
			die $ARG;
		}

		like(
			$ARG,
			qr/Confessing on an attempt to call execute/
		);
		$confessed = 1;
	};

	if ( $should_confess ) {
		ok( $confessed, 'A ConfessExecutor should die when asked to execute something' );
	}
	else {
		# use DDP colored => 1;
		# my $z = {
		# 	aln_dir => $aln_dir,
		# 	prof_dir => $prof_dir,
		# };
		# p $z;

		# sleep 100;

		ok( -s $prof_dir->child( 'n0de_63874226d07ddff227d07f8e95dd9b6e.mk_compass_db.prof' ) );
		ok( -s $prof_dir->child( 'n0de_fcbcc5744da427381c1d8ccd05e5ab34.mk_compass_db.prof' ) );
		ok( -s $prof_dir->child( 'n0de_fdb2c3bab9d0701c4a050a4d8d782c7f.mk_compass_db.prof' ) );
		ok( -s $aln_dir ->child( 'n0de_63874226d07ddff227d07f8e95dd9b6e.faa'                ) );
		ok( -s $aln_dir ->child( 'n0de_fcbcc5744da427381c1d8ccd05e5ab34.faa'                ) );
		ok( -s $aln_dir ->child( 'n0de_fdb2c3bab9d0701c4a050a4d8d782c7f.faa'                ) );
	}

	ok( 1 );
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

	# subtest 'test   for class ' . $executor_name, \&test_link_list_class, $executor_name, @{ dclone( $data ) };

	subtest
		'Executor ' . $executor_name . ' does TODOCUMENT',
		\&test_executor,
		$executor,
		( ( $executor_name =~ /confess/i ) || 0 )
}