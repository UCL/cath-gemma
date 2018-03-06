#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English     qw/ -no_match_vars /;
use FindBin;
use Time::HiRes qw/ usleep         /;

# Core (test)
use Test::More tests => 9;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;
use Try::Tiny;

# Non-core (test) (local)
use Test::Exception;

BEGIN{ use_ok( 'Cath::Gemma::Util') }

sub get_tempdir {
	return Path::Tiny->tempdir(
		TEMPLATE => ".run_and_time_filemaking_cmd.testdir.XXXXXXXXXXX",
		DIR      => '/tmp',
		TMPDIR   => 0,
	);
}

subtest 'simple' => sub {
	my $result = run_and_time_filemaking_cmd( 'test_fn', undef, sub { usleep( 100 ); return { key => 'value' }; } );
	use Carp qw/ cluck confess /;
	use Data::Dumper;

	foreach my $duration_key ( qw/ duration wrapper_duration / ) {
		ok( $result->{ $duration_key } );
		isa_ok( $result->{ $duration_key }, 'Time::Seconds' );
		delete $result->{ $duration_key };
	}

	is_deeply( $result, { 'out_filename' => undef, 'key' => 'value' }, 'Standard output has the result plus the out_filename' );
};

subtest 'run_and_time_filemaking_cmd() dies' => sub {
	dies_ok( sub { run_and_time_filemaking_cmd( 'test_fn', undef, sub { return    ; } ) }, 'Dies if the function returns empty' );
	dies_ok( sub { run_and_time_filemaking_cmd( 'test_fn', undef, sub { return [ ]; } ) }, 'Dies if the function returns a non-hash' );
	dies_ok( sub { run_and_time_filemaking_cmd( 'test_fn', undef, sub { die;        } ) }, 'Dies if the function dies' );
};

subtest 'run_and_time_filemaking_cmd() to non-empty file' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file     = path( $temp_test_dir )->child( 'test_file' );
	$out_file->spew( ' ' );
	lives_ok( sub { run_and_time_filemaking_cmd( 'test_fn', $out_file, sub { return {}; } ) }, 'Lives if the file is non-empty' );
};

subtest 'run_and_time_filemaking_cmd() to empty file' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file     = path( $temp_test_dir )->child( 'test_file' );
	$out_file->spew( '' );
	lives_ok( sub { run_and_time_filemaking_cmd( 'test_fn', $out_file, sub { return {}; } ) }, 'Lives if the file is empty' );
};

subtest 'run_and_time_filemaking_cmd() to non-existent file' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file     = path( $temp_test_dir )->child( 'test_file' );
	$out_file->spew( '' );
	lives_ok( sub { run_and_time_filemaking_cmd( 'test_fn', $out_file, sub { return {}; } ) }, 'Lives if the file is non-existent and in non-existent dir' );
};

subtest 'run_and_time_filemaking_cmd() to file in non-existent subdir' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file     = path( $temp_test_dir )->child( 'test_non_existent_subdir' )->child( 'test_non_existent_subdir' )->child( 'test_file' );
	lives_ok( sub { run_and_time_filemaking_cmd( 'test_fn', $out_file, sub { return {}; } ) }, 'Lives if the file is non-existent and in a non-existent subdir' );
};

subtest 'run_and_time_filemaking_cmd() to file in system dir' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file     = path( '/' )->child( 'subdir1' )->child( 'subdir2' )->child( 'test_file' );
	dies_ok( sub { run_and_time_filemaking_cmd( 'test_fn', $out_file, sub { return {}; } ) }, 'Dies if the file is non-existent and in a subdir of a system dir' );
};

subtest 'remove test_directory during run_and_time_filemaking_cmd()' => sub {
	my $temp_test_dir = get_tempdir();
	my $out_file = path( $temp_test_dir )->child( 'test_file' );
	try {
		run_and_time_filemaking_cmd(
			'test',
			$out_file,
			sub {
				$temp_test_dir->remove_tree( { safe => 0 } )
					or die 'An error occurred in trying to remove a test directory ' . $OS_ERROR;
				return { result => {} };
			}
		);
	}
	catch {
		like(
			$ARG,
			qr/Caught error when trying to atomically commit write/
		);
	};
}
