package Cath::Gemma::Compute::Task::BuildTreeTask;

=head1 NAME

Cath::Gemma::Compute::Task::BuildTreeTask - Define a Cath::Gemma::Compute::Task for GeMMA tree-building computations

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                      /;
use English             qw/ -no_match_vars               /;
use List::Util          qw/ min                          /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                        /;
use Object::Util;
use Path::Tiny;
use Types::Standard     qw/ ArrayRef Object Optional Str /;

# Cath::Gemma
use Cath::Gemma::Executor::DirectExecutor;
use Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder;
use Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder;
use Cath::Gemma::TreeBuilder::PureTreeBuilder;
use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
	CathGemmaHHSuiteProfileType
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskProfileDirSet
	CathGemmaDiskTreeDirSet
	CathGemmaNodeOrdering
	CathGemmaTreeBuilder
/;
use Cath::Gemma::Util;

=head2 dir_set

TODOCUMENT

=cut

has dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskTreeDirSet,
	default => sub { Cath::Gemma::Disk::TreeDirSet->new(); },
	handles => [ qw/
		aln_dir
		prof_dir
		scan_dir
		starting_cluster_dir
		tree_dir
	/ ],
	required => 1,
);

=head2 starting_cluster_lists

TODOCUMENT

=cut

has starting_cluster_lists =>(
	is          => 'ro',
	isa         => ArrayRef[ArrayRef[Str]],
	handles_via => 'Array',
	handles     => {
		is_empty      => 'is_empty',
		num_steps     => 'count',
		step_of_index => 'get',
	},
	required    => 1,
);

# !!!!!!!!! PLACED BELOW THE ATTRIBUTES THAT ARE USED TO SATISFY THIS ROLE !!!!!!!!!
with ( 'Cath::Gemma::Compute::Task' );

=head2 tree_builder

TODOCUMENT

=cut

has tree_builder => (
	is          => 'ro',
	isa         => CathGemmaTreeBuilder,
	required    => 1,
);


=head2 profile_build_type

TODOCUMENT

=cut

has profile_build_type =>(
	is       => 'ro',
	isa      => CathGemmaProfileType,
	default  => sub { default_profile_build_type(); },
	required => 1,
);

=head2 clusts_ordering

TODOCUMENT

=cut

has clusts_ordering =>(
	is       => 'ro',
	isa      => Optional[CathGemmaNodeOrdering],
	default  => sub { default_clusts_ordering(); },
	required => 1,
);

=head2 id

Return an ID for the Task, which should be different if there are differences in
any of the properties specifying what work should be done

=cut

sub id {
	my $self = shift;
	return generic_id_of_clusters( [
		$self->dir_set()->id(),
		$self->tree_builder()->name(),
		$self->profile_build_type(),
		$self->clusts_ordering(),
		map { id_of_clusters( $ARG ) } @{ $self->starting_cluster_lists() },
	] );
}

# =head2 starting_cluster_lists

# TODOCUMENT

# =cut

# has starting_cluster_lists => (
# 	is          => 'ro', # TODO: Can we get away with ro or does it need to be rwp?
# 	handles_via => 'Array',
# 	handles     => {
# 		is_empty       => 'is_empty',
# 		num_steps_impl => 'count',
# 		step_of_index  => 'get',
# 	},
# );

# =head2 remove_already_present

# TODOCUMENT

# =cut

# sub remove_already_present {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );

# 	my $starting_cluster_lists = $self->starting_cluster_lists();

# 	my @del_indices = grep {
# 		-s ( '' . $self->dir_set()->profile_file_of_starting_clusters      ( $starting_cluster_lists->[ $ARG ], $self->profile_build_type() ) )
# 		&&
# 		-s ( '' . $self->dir_set()->alignment_filename_of_starting_clusters( $starting_cluster_lists->[ $ARG ] ) )
# 	} ( 0 .. $#$starting_cluster_lists );

# 	foreach my $reverse_index ( reverse( @del_indices ) ) {
# 		splice( @$starting_cluster_lists, $reverse_index, 1 );
# 	}

# 	return $self;
# }

# # =head2 get_sub_task

# TODOCUMENT

# # =cut

# # sub get_sub_task {
# # 	state $check = compile( Object, Int, Int );
# # 	my ( $self, $begin, $end ) = $check->( @ARG );

# # 	return __PACKAGE__->new(
# # 		starting_cluster_lists => 0,
# # 		starting_cluster_dir   => $self->starting_cluster_dir(),
# # 		aln_dir                => $self->aln_dir(),
# # 		prof_dir               => $self->prof_dir(),
# # 	);
# # }

# =head2 total_num_starting_clusters

# TODOCUMENT

# =cut

# sub total_num_starting_clusters {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );

# 	return sum0( map { scalar( @$ARG ); } @{ $self->starting_cluster_lists() } );
# }

# =head2 execute_task

# TODOCUMENT

# =cut

# sub execute_task {
# 	state $check = compile( Object, CathGemmaDiskExecutables );
# 	my ( $self, $exes ) = $check->( @ARG );

# 	if ( ! $self->dir_set()->is_set() ) {
# 		warn "Cannot execute_task on a BuildTreeTask that doesn't have all its directories configured";
# 	}

# 	return [
# 		map
# 		{
# 			my $starting_clusters = $ARG;
# 			Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
# 				$exes,
# 				$starting_clusters,
# 				$self->dir_set(),
# 				$self->profile_build_type(),
# 			);
# 		}
# 		@{ $self->starting_cluster_lists() },
# 	];
# }

# =head2 split_into_singles

# TODOCUMENT

# =cut

# sub split_into_singles {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );

# 	return [
# 		map
# 			{ $self->$_clone( starting_cluster_lists => [ $ARG ] ); }
# 			@{ $self->starting_cluster_lists() }
# 	];
# }


=head2 split_into_singles

TODOCUMENT

=cut

sub split_into_singles {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [
		map
			{ $self->$_clone( starting_cluster_lists => [ $ARG ] ); }
			@{ $self->starting_cluster_lists() }
	];
}


# =head2 remove_duplicate_build_tasks

# TODOCUMENT

# =cut

# sub remove_duplicate_build_tasks {
# 	state $check = compile( Invocant, ArrayRef[CathGemmaComputeBuildTreeTask] );
# 	my ( $proto, $build_tasks ) = $check->( @ARG );

# 	if ( scalar( @$build_tasks ) ) {
# 		my $profile_build_type = $build_tasks->[ 0 ]->profile_build_type();
# 		my $dir_set            = $build_tasks->[ 0 ]->dir_set();

# 		if ( any { $ARG->profile_build_type() ne $profile_build_type } @$build_tasks ) {
# 			confess "Cannot remove_duplicate_build_tasks() for BuildTreeTasks with inconsistent profile_build_type()s";
# 		}
# 		if ( any { ! $ARG->dir_set()->is_equal_to( $dir_set ) } @$build_tasks ) {
# 			confess "Cannot remove_duplicate_build_tasks() for BuildTreeTasks with inconsistent dir_set()s";
# 		}

# 		my %prev_seen_ids;
# 		foreach my $build_task ( @$build_tasks ) {

# 			my $starting_cluster_lists = $build_task->starting_cluster_lists();
# 			my @del_indices = grep {

# 				my $id                = id_of_clusters( $starting_cluster_lists->[ $ARG ] );
# 				my $prev_seen         = $prev_seen_ids{ $id };
# 				$prev_seen_ids{ $id } = 1;
# 				$prev_seen;
# 			} ( 0 .. $#$starting_cluster_lists );

# 			foreach my $reverse_index ( reverse( @del_indices ) ) {
# 				splice( @$starting_cluster_lists, $reverse_index, 1 );
# 			}
# 		}
# 	}

# 	return $build_tasks;
# }

=head2 execute_task

TODOCUMENT

=cut

sub execute_task {
	my ( $self, $exes, $subtask_executor ) = @ARG;

	my $tree_builder               = $self->tree_builder();
	my $tree_dir_set               = $self->dir_set();
	my $profile_build_type         = $self->profile_build_type();
	my $clusts_ordering            = $self->clusts_ordering();
	my $tree_builder_name          = $tree_builder->name();
	my $tree_out_dir               = $self->tree_dir()->child( join( '.', $clusts_ordering, $profile_build_type, $tree_builder_name ) );

	my $profile_build_class        = profile_builder_class_from_type( $profile_build_type );

	return [
		map
		{
			my $starting_clusters = $ARG;

			INFO 'Building a tree with '
				. scalar( @$starting_clusters )
				. ' starting cluster(s) (beginning with '
				. join( ', ', @$starting_clusters[ 0 .. min( 20, $#$starting_clusters ) ] )
				. ')';

			my $tree = $tree_builder->build_tree(
				$exes,
				$subtask_executor,
				$starting_clusters,
				$tree_dir_set->gemma_dir_set(),
				$profile_build_type,
				$clusts_ordering,
			);

			# Ensure that all alignments have been built for a tree
			# (which may not be true if the tree was built under a naive method)
			INFO 'After having built a tree from '
				. scalar( @$starting_clusters )
				. ' starting cluster(s), (beginning with '
				. join( ', ', @$starting_clusters[ 0 .. min( 20, $#$starting_clusters ) ] )
				. ')... now ensuring that all alignments for the tree are present...';
			$tree->ensure_all_alignments(
				$clusts_ordering,
				$exes,
				$subtask_executor,
				$tree_dir_set->profile_dir_set(),
			);

			INFO 'Archiving a tree built from '
				. scalar( @$starting_clusters )
				. ' starting cluster(s), (beginning with '
				. join( ', ', @$starting_clusters[ 0 .. min( 20, $#$starting_clusters ) ] )
				. ')... in directory '
				. $tree_out_dir;
			$tree->archive_in_dir(
				'tree',
				$clusts_ordering,
				$tree_dir_set->aln_dir(),
				$tree_out_dir,
			);

			$profile_build_class->build_alignment_and_profile(
				$exes,
				$starting_clusters,
				$tree_dir_set->profile_dir_set(),
				$self->profile_build_type(),
			);
		}
		@{ $self->starting_cluster_lists() },
	];
}


=head2 estimate_time_to_execute_step_of_index

TODOCUMENT

# TODO: Make this estimate time more sensibly than assuming 1 second per profile step

=cut

sub estimate_time_to_execute_step_of_index {
	my ( $self, $index ) = @ARG;
	my $step = $self->step_of_index( $index );
	return Time::Seconds->new( 86400 ); # 86400 seconds = 1 day
}

=head2 make_batch_of_indices

TODOCUMENT

=cut

sub make_batch_of_indices {
	my ( $self, $start_index, $num_steps ) = @ARG;

	if ( $start_index + $num_steps > $self->num_steps() ) {
		confess 'Request to make a batch of steps that do not exist (indices requested: [ '
			. $start_index
			. ', '
			. ( $start_index + $num_steps )
			. ' ), num_steps available: '
			. $self->num_steps()
			. ')';
	}

	return Cath::Gemma::Compute::WorkBatch->new(
		tree_build_tasks => [
			$self->$_clone(
				starting_cluster_lists => [ @{ $self->starting_cluster_lists() } [ $start_index .. ( $start_index + $num_steps - 1 ) ] ]
			)
		],

	);
}

1;
