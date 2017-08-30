package Cath::Gemma::Compute::WorkBatch;

=head1 NAME

Cath::Gemma::Compute::WorkBatch - TODOCUMENT

It should be assumed that the scan_tasks may depend on the profile_tasks

=cut

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars   /;
use List::Util         qw/ sum0             /;
use Storable           qw/ freeze thaw      /;
use Storable           qw/ thaw             /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                    /;
use Path::Tiny;
use Type::Params       qw/ compile Invocant /;
use Types::Path::Tiny  qw/ Path             /;
use Types::Standard    qw/ ArrayRef Object  /;

# Cath
use Cath::Gemma::Compute::Task::BuildTreeTask;
use Cath::Gemma::Compute::Task::ProfileBuildTask;
use Cath::Gemma::Compute::Task::ProfileScanTask;
use Cath::Gemma::Types qw/
	CathGemmaComputeTaskBuildTreeTask
	CathGemmaComputeTaskProfileBuildTask
	CathGemmaComputeTaskProfileScanTask
	CathGemmaComputeWorkBatch
	CathGemmaDiskExecutables
	/;
use Cath::Gemma::Util;

=head2 profile_tasks

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

=cut

sub append {
	state $check = compile( Object, CathGemmaComputeWorkBatch );
	my ( $self, $rhs ) = $check->( @ARG );

	$self->_push_profile_tasks   ( @{ $rhs->profile_tasks  () } );
	$self->_push_scan_tasks      ( @{ $rhs->scan_tasks     () } );
	$self->_push_treebuild_tasks ( @{ $rhs->treebuild_tasks() } );
}

=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return generic_id_of_clusters( [ map { $ARG->id() } ( @{ $self->profile_tasks  () },
	                                                      @{ $self->scan_tasks     () },
	                                                      @{ $self->treebuild_tasks() } ) ] );
}

=head2 num_profile_steps

=cut

sub num_profile_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->profile_tasks() } );
}

=head2 num_scan_steps

=cut

sub num_scan_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->scan_tasks() } );
}

=head2 num_treebuild_steps

=cut

sub num_treebuild_steps {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_steps(); } @{ $self->treebuild_tasks() } );
}

=head2 remove_empty_profile_tasks

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

# =cut

# sub total_num_starting_clusters_in_profiles {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return sum0( map { $ARG->total_num_starting_clusters(); } @{ $self->profile_tasks() } );
# }

=head2 estimate_time_to_execute

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

=cut

sub execute_task {
	state $check = compile( Object, CathGemmaDiskExecutables );
	my ( $self, $exes ) = $check->( @ARG );

	INFO 'About to execute ' . scalar( @{ $self->profile_tasks  () } )
	   . ' profile tasks, '  . scalar( @{ $self->scan_tasks     () } )
	   . ' scan tasks and '  . scalar( @{ $self->treebuild_tasks() } )
	   . ' tree-build tasks';

	return [
		map
			{ $ARG->execute_task( $exes ); }
			(
				@{ $self->profile_tasks  () },
				@{ $self->scan_tasks     () },
				@{ $self->treebuild_tasks() },
			)
	];
}

=head2 to_string

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

=cut

sub write_to_file {
	state $check = compile( Object, Path );
	my ( $self, $file ) = $check->( @ARG );
	$file->spew( freeze( $self ) );
}

=head2 read_from_file

=cut

sub read_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $file ) = $check->( @ARG );

	return thaw( $file->slurp() );
}

=head2 execute_from_file

=cut

sub execute_from_file {
	state $check = compile( Invocant, Path, CathGemmaDiskExecutables );
	my ( $proto, $file, $exes ) = $check->( @ARG );

	return $proto->read_from_file( $file )->execute_task( $exes );
}

1;
