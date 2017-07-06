package Cath::Gemma::TreeBuilder;

=head1 NAME

Cath::Gemma::TreeBuilder - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars               /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile                      /;
use Types::Path::Tiny qw/ Path                         /;
use Types::Standard   qw/ ArrayRef Object Optional Str /;

# Cath
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Executor;
use Cath::Gemma::Scan::ScansDataFactory;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaExecutor
	CathGemmaNodeOrdering
/;

=head2 requires build_tree

=cut

requires 'build_tree';

=head2 requires name

=cut

requires 'name';

=head2 around build_tree

=cut

around build_tree => sub {
	my $orig = shift;

	state $check = compile( Object, CathGemmaExecutor, ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType, Optional[CathGemmaNodeOrdering] );
	my ( $self, $executor, $starting_clusters, $gemma_dir_set, $compass_profile_build_type, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	$executor->execute(

		# Build alignments and profiles for...
		[
			# ...all starting_clusters
			Cath::Gemma::Compute::Task::ProfileBuildTask->new(
				starting_cluster_lists     => [ map { [ $ARG ] } @$starting_clusters ],
				dir_set                    => $gemma_dir_set->profile_dir_set(),
				compass_profile_build_type => $compass_profile_build_type,
			)->remove_already_present(),
		],

		# Perform scans for...
		[
			# ...all initial nodes (ie starting cluster vs other starting clusters)
			Cath::Gemma::Compute::Task::ProfileScanTask->new(
				starting_cluster_list_pairs => Cath::Gemma::Tree::MergeList->inital_scan_lists_of_starting_clusters( $starting_clusters ),
				dir_set                     => $gemma_dir_set,
				compass_profile_build_type  => $compass_profile_build_type,
			),
		]
	);

	my $scans_data = Cath::Gemma::Scan::ScansDataFactory->load_scans_data_of_starting_clusters_and_gemma_dir_set(
		$starting_clusters,
		$gemma_dir_set,
		$compass_profile_build_type,
	);

	if ( scalar ( @ARG ) < 6 ) {
		push @ARG, $clusts_ordering;
	}

	push @ARG, $scans_data;

	$orig->( @ARG );
};

1;