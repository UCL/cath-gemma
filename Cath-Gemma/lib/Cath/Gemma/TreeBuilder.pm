package Cath::Gemma::TreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder - Define a Moo::Role for building trees; ensure that each TreeBuilder gets complete all-vs-all ScansData

=cut

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars               /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                        /;
use Type::Params        qw/ compile                      /;
use Types::Path::Tiny   qw/ Path                         /;
use Types::Standard     qw/ ArrayRef Object Optional Str /;

# Cath::Gemma
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Executor;
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Tree::MergeList;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
	CathGemmaExecutor
	CathGemmaNodeOrdering
/;
use Cath::Gemma::Util;

=head2 requires build_tree

Require that a consumer of the TreeBuilder role must provide a build_tree() method that builds a tree

=cut

requires 'build_tree';

=head2 requires name

Require that a consumer of the TreeBuilder role must provide a name() method that returns its name

=cut

requires 'name';

=head2 around build_tree

Before calling the consuming class's build_tree() method, ensure that an all-against-all scan has been
completed and include the resulting ScansData in the call to the concrete build_tree().

This uses `around` rather than `before` so it can substantially modify the @ARG that gets passed to the
consuming class's build_tree() method

=cut

around build_tree => sub {
	my $orig = shift;

	require Cath::Gemma::Compute::WorkBatchList;

	state $check = compile( Object, CathGemmaDiskExecutables, CathGemmaExecutor, ArrayRef[Str], CathGemmaDiskGemmaDirSet, Optional[CathGemmaProfileType], Optional[CathGemmaNodeOrdering] );
	my ( $self, $exes, $executor, $starting_clusters, $gemma_dir_set, $profile_build_type, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering      //= default_clusts_ordering();
	$profile_build_type   //= default_profile_build_type();

	DEBUG 'About to determine what steps if any are required to prepare all-vs-all scan results of the starting clusters';

	my $pre_work_batch_list = Cath::Gemma::Compute::WorkBatchList->new(
		batches => [ Cath::Gemma::Compute::WorkBatch->new(
			# Build alignments and profiles for...
			profile_tasks => [
				# ...all starting_clusters
				Cath::Gemma::Compute::Task::ProfileBuildTask->new(
					starting_cluster_lists     => [ map { [ $ARG ] } @$starting_clusters ],
					dir_set                    => $gemma_dir_set->profile_dir_set(),
					profile_build_type         => $profile_build_type,
				)->remove_already_present(),
			],

			# Perform scans for...
			scan_tasks => [
				# ...all initial nodes (ie starting cluster vs other starting clusters)
				Cath::Gemma::Compute::Task::ProfileScanTask->new(
					clust_and_clust_list_pairs => Cath::Gemma::Tree::MergeList->inital_scan_lists_of_starting_clusters( $starting_clusters ),
					dir_set                    => $gemma_dir_set,
					profile_build_type         => $profile_build_type,
				)->remove_already_present(),
			]
		) ]
	);
	if ( $pre_work_batch_list->num_steps() > 0 ) {
		DEBUG
			'In '
			. __PACKAGE__
			. '->build_tree(), made a work_batch_list of '
			. $pre_work_batch_list->num_steps()
			. ' steps, estimated to take up to '
			. $pre_work_batch_list->estimate_time_to_execute()
			. ' seconds';
		$executor->execute_batch_list( $pre_work_batch_list, 'always_wait_for_complete' );
	}
	else {
		DEBUG 'No steps required.'
	}

	INFO 'About to load the all-vs-all scans between the starting clusters of the tree';
	my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_gemma_dir_set(
		$gemma_dir_set,
		$profile_build_type,
		$starting_clusters,
	);
	INFO 'Finished loading the all-vs-all scans';

	if ( scalar ( @ARG ) < 6 ) {
		push @ARG, $profile_build_type;
	}

	if ( scalar ( @ARG ) < 7 ) {
		push @ARG, $clusts_ordering;
	}

	push @ARG, $scans_data;

	$orig->( @ARG );
};

1;