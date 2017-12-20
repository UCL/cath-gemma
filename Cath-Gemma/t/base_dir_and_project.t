#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 1;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
use Cath::Gemma::Disk::BaseDirAndProject;

is_deeply(
	Cath::Gemma::Disk::BaseDirAndProject->new(
		base_dir => path( '/tmp' ),
		project  => '1.10.8.10',
	)->get_project_subdir_of_subdir( 'files' ),
	path( '/tmp/files/1.10.8.10' )
);
