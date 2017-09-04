use strict;
use warnings;

# Core
use English qw/ -no_match_vars /;
use FindBin;
use Storable qw/ freeze thaw /;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

use Test::More tests => 3;

# Non-core (local)
use JSON::MaybeXS;
use Path::Tiny;

use Cath::Gemma::Util;

# my $bootstrap_tests = $ENV{ BOOTSTRAP_TESTS } // 0;
# my $test_basename   = path( $PROGRAM_NAME )->basename( '.t' );
my $data_dir        = path( 'data' );

use_ok( 'Cath::Gemma::Compute::Task::ProfileBuildTask' );

my $starting_cluster_dir = $data_dir->child( 'starting_clusters' );

=head2 make_example_profile_build_task

TODOCUMENT

=cut

sub make_example_profile_build_task {
	return Cath::Gemma::Compute::Task::ProfileBuildTask->new(
		starting_cluster_lists     => [ [ qw/ a b / ] ],
		compass_profile_build_type => default_compass_profile_build_type(),
		dir_set                    => Cath::Gemma::Disk::ProfileDirSet->new(
			starting_cluster_dir => $starting_cluster_dir,
			aln_dir              => path( 'dummy_aln_dir'  ),
			prof_dir             => path( 'dummy_prof_dir' ),
		),
	);
}

subtest 'constructs_without_error' => sub {
	plan tests => 1;
	new_ok( 'Cath::Gemma::Compute::Task::ProfileBuildTask' => [
		starting_cluster_lists     => [ [ qw/ a b / ] ],
		compass_profile_build_type => default_compass_profile_build_type(),
		dir_set                    => Cath::Gemma::Disk::ProfileDirSet->new(
			starting_cluster_dir => $starting_cluster_dir,
			aln_dir              => path( 'dummy_aln_dir'  ),
			prof_dir             => path( 'dummy_prof_dir' ),
		),
	] );
};

subtest 'freezes_and_thaws_to_orig' => sub {
	plan tests => 1;
	is_deeply(
		thaw( freeze( make_example_profile_build_task() ) ),
		make_example_profile_build_task()
	);
};

# done_testing();
