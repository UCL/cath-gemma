package Cath::Gemma::Compute::WorkBatch;

=head1 NAME

Cath::Gemma::Compute::WorkBatch - A batch of tasks (corresponding to a single HPC job when run under SpawnExecutor with SpawnHpcSgeRunner)

It should be assumed that the scan_tasks may depend on the profile_tasks

=cut

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars                                      /;
use List::Util          qw/ sum0                                                /;
use Storable            qw/ freeze thaw                                         /;
use Storable            qw/ thaw                                                /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                                               /;
use Path::Tiny;
use Type::Params        qw/ compile Invocant                                    /;
use Types::Path::Tiny   qw/ Path                                                /;
use Types::Standard     qw/ ArrayRef ClassName Object Optional slurpy Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Compute::Task::BuildTreeTask;
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Types qw/
	CathGemmaProfileType
	CathGemmaComputeTaskBuildTreeTask
	CathGemmaComputeTaskProfileBuildTask
	CathGemmaComputeTaskProfileScanTask
	CathGemmaComputeWorkBatch
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
	CathGemmaExecutor
	/;
use Cath::Gemma::Util;

=head2 profile_tasks

TODOCUMENT

=cut

has profile_tasks => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaComputeTaskProfileBuildTask],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_push_profile_tasks    => 'push',
		num_profile_tasks      => 'count',
		profile_task_of_index  => 'get',
		profile_tasks_is_empty => 'is_empty',
	}
);

=head2 scan_tasks

TODOCUMENT

=cut

has scan_tasks => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaComputeTaskProfileScanTask],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_push_scan_tasks    => 'push',
		num_scan_tasks      => 'count',
		scan_task_of_index  => 'get',
		scan_tasks_is_empty => 'is_empty',
	}
);

=head2 treebuild_tasks

TODOCUMENT

=cut

has treebuild_tasks => (
	is          => 'rwp',
	isa         => ArrayRef[CathGemmaComputeTaskBuildTreeTask],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_push_treebuild_tasks    => 'push',
		num_treebuild_tasks      => 'count',
		treebuild_task_of_index  => 'get',
		treebuild_tasks_is_empty => 'is_empty',
	}
);

=head2 is_empty

TODOCUMENT

=cut

sub is_empty {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return (
		$self->profile_tasks_is_empty()
		&&
		$self->scan_tasks_is_empty()
		&&
		$self->treebuild_tasks_is_empty()
	);
}


=head2 append

TODOCUMENT

=cut

sub append {
	state $check = compile( Object, CathGemmaComputeWorkBatch );
	my ( $self, $rhs ) = $check->( @ARG );

	$self->_push_profile_tasks   ( @{ $rhs->profile_tasks  () } );
	$self->_push_scan_tasks      ( @{ $rhs->scan_tasks     () } );
	$self->_push_treebuild_tasks ( @{ $rhs->treebuild_tasks() } );
}

=head2 id

TODOCUMENT

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return generic_id_of_clusters( [ map { $ARG->id() } ( @{ $self->profile_tasks  () },
	                                                      @{ $self->scan_tasks     () },
	                                                      @{ $self->treebuild_tasks() } ) ] );
}

=head2 num_profile_steps

TODOCUMENT

=cut

sub num_profile_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->profile_tasks() } );
}

=head2 num_scan_steps

TODOCUMENT

=cut

sub num_scan_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->scan_tasks() } );
}

=head2 num_treebuild_steps

TODOCUMENT

=cut

sub num_treebuild_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->treebuild_tasks() } );
}

=head2 num_steps

TODOCUMENT

=cut

sub num_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return (
		  $self->num_profile_steps()
		+ $self->num_scan_steps()
		+ $self->num_treebuild_steps()
	);
}

=head2 remove_empty_profile_tasks

TODOCUMENT

=cut

sub remove_empty_profile_tasks {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $tasks = $self->profile_tasks();
	my @del_indices = grep { $tasks->[ $ARG ]->is_empty(); } ( 0 .. $#$tasks );
	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @$tasks, $reverse_index, 1 );
	}
	return $self;
}

=head2 remove_empty_scan_tasks

TODOCUMENT

=cut

sub remove_empty_scan_tasks {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $tasks = $self->scan_tasks();
	my @del_indices = grep { $tasks->[ $ARG ]->is_empty(); } ( 0 .. $#$tasks );
	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @$tasks, $reverse_index, 1 );
	}
	return $self;
}

=head2 remove_empty_treebuild_tasks

TODOCUMENT

=cut

sub remove_empty_treebuild_tasks {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $tasks = $self->treebuild_tasks();
	my @del_indices = grep { $tasks->[ $ARG ]->is_empty(); } ( 0 .. $#$tasks );
	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @$tasks, $reverse_index, 1 );
	}
	return $self;
}

=head2 remove_empty_tasks

TODOCUMENT

=cut

sub remove_empty_tasks {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	$self->remove_empty_profile_tasks();
	$self->remove_empty_scan_tasks();
	$self->remove_empty_treebuild_tasks();
	return $self;
}

# =head2 total_num_starting_clusters_in_profiles

# TODOCUMENT

# =cut

# sub total_num_starting_clusters_in_profiles {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return sum0( map { $ARG->total_num_starting_clusters(); } @{ $self->profile_tasks() } );
# }

=head2 estimate_time_to_execute

TODOCUMENT

=cut

sub estimate_time_to_execute {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0(
		map
			{ $ARG->estimate_time_to_execute(); }
			(
				@{ $self->profile_tasks  () },
				@{ $self->scan_tasks     () },
				@{ $self->treebuild_tasks() },
			)
	);

}

=head2 execute_task

TODOCUMENT

=cut

sub execute_task {
	state $check = compile( Object, CathGemmaDiskExecutables, CathGemmaExecutor );
	my ( $self, $exes, $subtask_executor ) = $check->( @ARG );

	INFO 'About to execute ' . scalar( @{ $self->profile_tasks  () } )
	   . ' profile tasks, '  . scalar( @{ $self->scan_tasks     () } )
	   . ' scan tasks and '  . scalar( @{ $self->treebuild_tasks() } )
	   . ' tree-build tasks';

	return [
		map
			{ $ARG->execute_task( $exes, $subtask_executor ); }
			(
				@{ $self->profile_tasks  () },
				@{ $self->scan_tasks     () },
				@{ $self->treebuild_tasks() },
			)
	];
}

=head2 to_string

TODOCUMENT

=cut

sub to_string {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return 'WorkBatch['
		. $self->num_profile_tasks()
		. ' profile tasks'
		. (
			( $self->num_profile_tasks() > 0 )
			? ' (with nums of steps: '
				. join( ', ', map { $ARG->num_steps(); } @{ $self->profile_tasks() } )
				. ')'
			: ''
		)
		. '; '
		. $self->num_scan_tasks()
		. ' scan tasks'
		. (
			( $self->num_scan_tasks() > 0 )
			? ' (with nums of steps: '
				. join( ', ', map { $ARG->num_steps(); } @{ $self->scan_tasks() } )
				. ')'
			: ''
		)
		. '; '
		. $self->num_treebuild_tasks()
		. ' treebuild tasks'
		. (
			( $self->num_treebuild_tasks() > 0 )
			? ' (with nums of steps: '
				. join( ', ', map { $ARG->num_steps(); } @{ $self->treebuild_tasks() } )
				. ')'
			: ''
		)
		. ']';
}

=head2 write_to_file

TODOCUMENT

=cut

sub write_to_file {
	state $check = compile( Object, Path );
	my ( $self, $file ) = $check->( @ARG );
	$file->spew( freeze( $self ) );
}

=head2 read_from_file

TODOCUMENT

=cut

sub read_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $file ) = $check->( @ARG );

	return thaw( $file->slurp() );
}

=head2 execute_from_file

TODOCUMENT

=cut

sub execute_from_file {
	state $check = compile( Invocant, Path, CathGemmaDiskExecutables, CathGemmaExecutor );
	my ( $proto, $file, $exes, $subtask_executor ) = $check->( @ARG );

	# use Carp qw/ confess /;

	# my $stuff = $proto->read_from_file( $file )->profile_tasks();

	# use DDP colored => 1;
	# p $stuff;

	# use Data::Dumper;
	# confess Dumper( $stuff ) . ' ';

	# confess ' ';

	return $proto->read_from_file( $file )->execute_task( $exes, $subtask_executor );
}

=head2  make_work_batch_of_query_scs_and_match_scs_list

TODOCUMENT

=cut

sub make_work_batch_of_query_scs_and_match_scs_list {
	state $check = compile( ClassName, ArrayRef[Tuple[ArrayRef[Str], ArrayRef[Str]]], CathGemmaDiskGemmaDirSet, Optional[CathGemmaProfileType] );
	my ( $class, $query_scs_and_match_scs_list, $gemma_dir_set, $profile_build_type ) = $check->( @ARG );

	$profile_build_type //= default_profile_build_type();

	return Cath::Gemma::Compute::WorkBatch->new(
		profile_tasks => Cath::Gemma::Compute::Task::ProfileBuildTask->remove_duplicate_build_tasks( [
			Cath::Gemma::Compute::Task::ProfileBuildTask->new(
				starting_cluster_lists     => [ map { $ARG->[ 0 ]; } @$query_scs_and_match_scs_list ],
				dir_set                    => $gemma_dir_set->profile_dir_set(),
				profile_build_type         => $profile_build_type,
			)->remove_already_present(),
		] ),

		scan_tasks => Cath::Gemma::Compute::Task::ProfileScanTask->remove_duplicate_scan_tasks( [
			Cath::Gemma::Compute::Task::ProfileScanTask->new(
				clust_and_clust_list_pairs => [
					map {
						my $query_scs_and_match_scs = $ARG;
						[
							id_of_clusters( $query_scs_and_match_scs->[ 0 ] ),
							$query_scs_and_match_scs->[ 1 ],
						];
					} @$query_scs_and_match_scs_list
				],
				dir_set                    => $gemma_dir_set,
				profile_build_type         => $profile_build_type,
			)->remove_already_present(),
		] ),
	)->remove_empty_tasks();
}

=head2 make_from_profile_build_task_ctor_args

Make a WorkBatch containing one ProfileBuildTask, built from the specified ctor arguments

The arguments must include dir_set, which must specify a Cath::Gemma::Disk::ProfileDirSet

=cut

sub make_from_profile_build_task_ctor_args {
	state $check = compile( ClassName, slurpy ArrayRef, );
	my ( $class, $other_args ) = $check->( @ARG );

	return Cath::Gemma::Compute::WorkBatch->new(
		profile_tasks => [ Cath::Gemma::Compute::Task::ProfileBuildTask->new( @$other_args ) ]
	);
}

=head2 make_from_profile_scan_task_ctor_args

Make a WorkBatch containing one ProfileScanTask, built from the specified ctor arguments

The arguments must include dir_set, which must specify a Cath::Gemma::Disk::CathGemmaDiskGemmaDirSet

=cut

sub make_from_profile_scan_task_ctor_args {
	state $check = compile( ClassName, slurpy ArrayRef, );
	my ( $class, $other_args ) = $check->( @ARG );

	return Cath::Gemma::Compute::WorkBatch->new(
		scan_tasks => [ Cath::Gemma::Compute::Task::ProfileScanTask->new( @$other_args ) ]
	);
}

=head2 make_from_build_tree_task_ctor_args

Make a WorkBatch containing one BuildTreeTask, built from the specified ctor arguments

The arguments must include:
 * dir_set, which must specify a Cath::Gemma::Disk::CathGemmaDiskTreeDirSet
 * starting_cluster_lists
 * tree_builder

=cut

sub make_from_build_tree_task_ctor_args {
	state $check = compile( ClassName, slurpy ArrayRef, );
	my ( $class, $other_args ) = $check->( @ARG );

	return Cath::Gemma::Compute::WorkBatch->new(
		treebuild_tasks => [ Cath::Gemma::Compute::Task::BuildTreeTask->new( @$other_args ) ]
	);
}

=head2 batches_have_distinct_ids

Return whether the specified WorkBatches have distinct IDs

if ( ! Cath::Gemma::Compute::WorkBatch->batches_have_distinct_ids( [ $batch_a, $batch_b, $batch_c ] ) ) {
	panic();
}

=cut

sub batches_have_distinct_ids {
	state $check = compile( ClassName, ArrayRef[CathGemmaComputeWorkBatch] );
	my ( $class, $batches ) = $check->( @ARG );

	my $num_distinct_ids = scalar( unique_by_hashing( sort( map { $ARG->id() } @$batches ) ) );
	return $num_distinct_ids == scalar( @$batches );
}

1;
