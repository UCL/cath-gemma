#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English qw/ -no_match_vars /;
use FindBin;

# Core (test)
use Test::More tests => 1;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;
use Try::Tiny;

# Cath::Gemma
use Cath::Gemma::Util;

my $temp_test_dir = Path::Tiny->tempdir(
	TEMPLATE => "run_and_time_filemaking_cmd.testdir.XXXXXXXXXXX",
	DIR      => '/tmp',
	TMPDIR   => 0,
);

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
