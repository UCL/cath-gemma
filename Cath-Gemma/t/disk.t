#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Storable qw/ dclone /;
use FindBin;

# Core (test)
use Test::More tests => 6;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Non-core (test) (local)
use Test::Exception;

# Cath::Gemma
use Cath::Gemma::Util;

BEGIN { use_ok( 'Cath::Gemma::Disk::BaseDirAndProject' ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::GemmaDirSet'       ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::ProfileDirSet'     ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::TreeDirSet'        ) }

my $base_dir    = path( '/my_base' );
my $project     = 'a_proj';
my $strt_clusts = [ qw/ sc_9 sc_10 / ];

subtest 'Cath::Gemma::Disk::BaseDirAndProject' => sub {

	my $bdap_no_proj = new_ok( 'Cath::Gemma::Disk::BaseDirAndProject' => [ base_dir => $base_dir                      ] );
	my $bdap_wi_proj = new_ok( 'Cath::Gemma::Disk::BaseDirAndProject' => [ base_dir => $base_dir, project => $project ] );

	is( $bdap_no_proj->get_project_subdir_of_subdir( 'child' ), path( '/my_base/child'        ), 'Subdir is correct with no project' );
	is( $bdap_wi_proj->get_project_subdir_of_subdir( 'child' ), path( '/my_base/child/a_proj' ), 'Subdir is correct with a project'  );
};

subtest 'Cath::Gemma::Disk::ProfileDirSet' => sub {

	subtest 'create from base dir' => sub {

		my $prof_dirset = Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir( $base_dir );
		isa_ok( $prof_dirset, 'Cath::Gemma::Disk::ProfileDirSet' );

		is( $prof_dirset->aln_dir             (), path( '/my_base/alignments'        ) );
		is( $prof_dirset->prof_dir            (), path( '/my_base/profiles'          ) );
		is( $prof_dirset->starting_cluster_dir(), path( '/my_base/starting_clusters' ) );

		is( $prof_dirset->alignment_filename_of_starting_clusters( $strt_clusts                                       ), path( '/my_base/alignments/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.aln'              ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts                                       ), path( '/my_base/profiles/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts, default_compass_profile_build_type() ), path( '/my_base/profiles/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->prof_file_of_aln_file                  ( 'my_aln_file'                                      ), path( '/my_base/profiles/my_aln_file.mk_compass_db.prof'                           ) );

		ok(   $prof_dirset->is_equal_to( dclone( $prof_dirset ) ) );
		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir( 'other'   ) ) );
	};

	subtest 'create from base dir and project' => sub {

		my $prof_dirset = Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir_and_project( $base_dir, $project );
		isa_ok( $prof_dirset, 'Cath::Gemma::Disk::ProfileDirSet' );

		is( $prof_dirset->aln_dir             (), path( '/my_base/alignments/a_proj'        ) );
		is( $prof_dirset->prof_dir            (), path( '/my_base/profiles/a_proj'          ) );
		is( $prof_dirset->starting_cluster_dir(), path( '/my_base/starting_clusters/a_proj' ) );

		is( $prof_dirset->alignment_filename_of_starting_clusters( $strt_clusts                                       ), path( '/my_base/alignments/a_proj/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.aln'              ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts                                       ), path( '/my_base/profiles/a_proj/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts, default_compass_profile_build_type() ), path( '/my_base/profiles/a_proj/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->prof_file_of_aln_file                  ( 'my_aln_file'                                      ), path( '/my_base/profiles/a_proj/my_aln_file.mk_compass_db.prof'                           ) );

		ok(   $prof_dirset->is_equal_to( dclone( $prof_dirset ) ) );
		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir( 'other' ) ) );
	};

	subtest 'create using new without arguments' => sub {

		my $emptyprof_dirset = new_ok( 'Cath::Gemma::Disk::ProfileDirSet' );
		dies_ok( sub { $emptyprof_dirset->assert_is_set                          (              ) } );
		dies_ok( sub { $emptyprof_dirset->alignment_filename_of_starting_clusters( $strt_clusts ) } );
		dies_ok( sub { $emptyprof_dirset->aln_dir                                (              ) } );
		dies_ok( sub { $emptyprof_dirset->prof_dir                               (              ) } );
		dies_ok( sub { $emptyprof_dirset->starting_cluster_dir                   (              ) } );
	};

	subtest 'create using new with starting_cluster_dir' => sub {

		my $emptyprof_dirset = new_ok( 'Cath::Gemma::Disk::ProfileDirSet' => [ starting_cluster_dir => path('/sc') ] );
		dies_ok( sub { $emptyprof_dirset->assert_is_set() } );
	};

	subtest 'create using new with starting_cluster_dir and aln_dir' => sub {

		my $emptyprof_dirset = new_ok( 'Cath::Gemma::Disk::ProfileDirSet' => [ starting_cluster_dir => path('/sc'), aln_dir => path('/al') ] );
		dies_ok( sub { $emptyprof_dirset->assert_is_set() } );
	};

	subtest 'create using new with starting_cluster_dir, aln_dir and prof_dir' => sub {

		my $prof_dirset = new_ok( 'Cath::Gemma::Disk::ProfileDirSet' => [
			aln_dir              => path( '/al_dir' ),
			prof_dir             => path( '/pr_dir' ),
			starting_cluster_dir => path( '/sc_dir' ),
		] );

		is( $prof_dirset->aln_dir             (), path( '/al_dir' ) );
		is( $prof_dirset->prof_dir            (), path( '/pr_dir' ) );
		is( $prof_dirset->starting_cluster_dir(), path( '/sc_dir' ) );

		is( $prof_dirset->alignment_filename_of_starting_clusters( $strt_clusts                                       ), path( '/al_dir/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.aln'                ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts                                       ), path( '/pr_dir/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->compass_file_of_starting_clusters      ( $strt_clusts, default_compass_profile_build_type() ), path( '/pr_dir/n0de_a9f487f69b1ace1a7ff19353a9d2e7c4.mk_compass_db.prof' ) );
		is( $prof_dirset->prof_file_of_aln_file                  ( 'my_aln_file'                                      ), path( '/pr_dir/my_aln_file.mk_compass_db.prof'                           ) );

		ok(   $prof_dirset->is_equal_to( dclone( $prof_dirset ) ) );
		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir( 'other' ) ) );

		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->new(
			aln_dir              => path( '/al_dir2' ),
			prof_dir             => path( '/pr_dir'  ),
			starting_cluster_dir => path( '/sc_dir'  ),
		) ) );

		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->new(
			aln_dir              => path( '/al_dir'  ),
			prof_dir             => path( '/pr_dir2' ),
			starting_cluster_dir => path( '/sc_dir'  ),
		) ) );

		ok( ! $prof_dirset->is_equal_to( Cath::Gemma::Disk::ProfileDirSet->new(
			aln_dir              => path( '/al_dir'  ),
			prof_dir             => path( '/pr_dir'  ),
			starting_cluster_dir => path( '/sc_dir2' ),
		) ) );
	};
};

# subtest 'Cath::Gemma::Disk::GemmaDirSet' => sub {
#
# };

# subtest 'Cath::Gemma::Disk::TreeDirSet' => sub {
#
# };
