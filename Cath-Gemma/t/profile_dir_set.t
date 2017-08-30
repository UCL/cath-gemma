use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 5;

# Non-core (local)
use Path::Tiny;

# Cath
use Cath::Gemma::Disk::BaseDirAndProject;
use Cath::Gemma::Disk::ProfileDirSet;


my $base_dir_and_proj = Cath::Gemma::Disk::BaseDirAndProject->new(
	base_dir => path( '/tmp' ),
	project  => '1.10.8.10',
);

is(
	Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => $base_dir_and_proj )->starting_cluster_dir(),
	path( '/tmp/starting_clusters/1.10.8.10' )
);

is(
	Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => $base_dir_and_proj )->aln_dir(),
	path( '/tmp/alignments/1.10.8.10' )
);

is(
	Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => $base_dir_and_proj )->prof_dir(),
	path( '/tmp/profiles/1.10.8.10' )
);


is(
	Cath::Gemma::Disk::ProfileDirSet->new(
		base_dir_and_project => $base_dir_and_proj,
		starting_cluster_dir => path( '/geoff' ),
	)->starting_cluster_dir(),
	path( '/geoff' )
);

is(
	Cath::Gemma::Disk::ProfileDirSet->new(
		base_dir_and_project => $base_dir_and_proj,
		starting_cluster_dir => path( '/geoff' ),
	)->prof_dir(),
	path( '/tmp/profiles/1.10.8.10' )
);
