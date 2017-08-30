use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 1;

# Non-core (local)
use Path::Tiny;

# Cath
use Cath::Gemma::Disk::BaseDirAndProject;

is_deeply(
	Cath::Gemma::Disk::BaseDirAndProject->new(
		base_dir => path( '/tmp' ),
		project  => '1.10.8.10',
	)->get_project_subdir_of_subdir( 'files' ),
	path( '/tmp/files/1.10.8.10' )
);
