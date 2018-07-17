#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 6;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Cath::Gemma
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

subtest 'id gives distinct MD5 format string' => sub {
	my $id_a = Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => $base_dir_and_proj )->id();
	# Different base_dir
	my $id_b = Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
		base_dir => path( '/opt' ),
		project  => $base_dir_and_proj->project(),
	) )->id();
	# Different project
	my $id_c = Cath::Gemma::Disk::ProfileDirSet->new( base_dir_and_project => Cath::Gemma::Disk::BaseDirAndProject->new(
		base_dir => $base_dir_and_proj->base_dir(),
		project  => '2.60.40.10',
	) )->id();

	foreach my $id ( $id_a, $id_b, $id_c ) {
		like( $id, qr/^[a-z0-9]{32}$/, 'ProfileDirSet id is MD5-format string' );
	}

	isnt( $id_b, $id_a, 'Different ProfileDirSets give different IDs' );
	isnt( $id_c, $id_a, 'Different ProfileDirSets give different IDs' );
	isnt( $id_c, $id_b, 'Different ProfileDirSets give different IDs' );
}
