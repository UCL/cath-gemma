package Cath::Gemma::Compute::Task::ProfileBuildTask;

use strict;
use warnings;

# Core
use Carp               qw/ confess                 /;
use English            qw/ -no_match_vars          /;
use List::Util         qw/ any min                 /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                   /;
use Object::Util;
use Path::Tiny;
use Type::Params        qw/ compile Invocant        /;
use Types::Path::Tiny   qw/ Path                    /;
use Types::Standard     qw/ ArrayRef Int Object Str /;

# Cath::Gemma
use Cath::Gemma::Disk::ProfileDirSet;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaComputeTaskProfileBuildTask
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 dir_set

TODOCUMENT

=cut

has dir_set  => (
	is       => 'ro',
	isa      => CathGemmaDiskProfileDirSet,
	default  => sub { Cath::Gemma::Disk::ProfileDirSet->new(); },
	handles  => [ qw/
		aln_dir
		prof_dir
		starting_cluster_dir
	/ ],
	required => 1,
);

=head2 starting_cluster_lists

TODOCUMENT

=cut

has starting_cluster_lists => (
	is          => 'ro', # TODO: Can we get away with ro or does it need to be rwp?
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

=head2 compass_profile_build_type

TODOCUMENT

=cut

has compass_profile_build_type => (
	is       => 'ro',
	isa      => CathGemmaCompassProfileType,
	required => 1,
);

=head2 id

TODOCUMENT

=cut

sub id {
	my $self = shift;
	return generic_id_of_clusters( [
		$self->compass_profile_build_type(),
		map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() }
	] );
}

=head2 remove_already_present

TODOCUMENT

=cut

sub remove_already_present {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $starting_cluster_lists = $self->starting_cluster_lists();

	my @del_indices = grep {
		-s ( '' . $self->dir_set()->compass_file_of_starting_clusters      ( $starting_cluster_lists->[ $ARG ], $self->compass_profile_build_type() ) )
		&&
		-s ( '' . $self->dir_set()->alignment_filename_of_starting_clusters( $starting_cluster_lists->[ $ARG ] ) )
	} ( 0 .. $#$starting_cluster_lists );

	foreach my $reverse_index ( reverse( @del_indices ) ) {
		splice( @$starting_cluster_lists, $reverse_index, 1 );
	}

	return $self;
}

# =head2 get_sub_task

# TODOCUMENT

# =cut

# sub get_sub_task {
# 	state $check = compile( Object, Int, Int );
# 	my ( $self, $begin, $end ) = $check->( @ARG );

# 	return __PACKAGE__->new(
# 		starting_cluster_lists => 0,
# 		starting_cluster_dir   => $self->starting_cluster_dir(),
# 		aln_dir                => $self->aln_dir(),
# 		prof_dir               => $self->prof_dir(),
# 	);
# }

=head2 total_num_starting_clusters

TODOCUMENT

=cut

sub total_num_starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return sum0( map { scalar( @$ARG ); } @{ $self->starting_cluster_lists() } );
}

=head2 execute_task

TODOCUMENT

=cut

sub execute_task {
	my ( $self, $exes ) = @ARG;

	return [
		map
		{
			my $starting_clusters = $ARG;
			INFO 'Building profile for '
				. scalar( @$starting_clusters )
				. ' starting cluster(s) (beginning with '
				. join( ', ', @$starting_clusters[ 0 .. min( 20, $#$starting_clusters ) ] )
				. ')';
			Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
				$exes,
				$starting_clusters,
				$self->dir_set(),
				$self->compass_profile_build_type(),
			);
		}
		@{ $self->starting_cluster_lists() },
	];
}

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

=head2 remove_duplicate_build_tasks

TODOCUMENT

=cut

sub remove_duplicate_build_tasks {
	state $check = compile( Invocant, ArrayRef[CathGemmaComputeTaskProfileBuildTask] );
	my ( $proto, $build_tasks ) = $check->( @ARG );

	if ( scalar( @$build_tasks ) ) {
		my $compass_profile_build_type = $build_tasks->[ 0 ]->compass_profile_build_type();
		my $dir_set                    = $build_tasks->[ 0 ]->dir_set();

		if ( any { $ARG->compass_profile_build_type() ne $compass_profile_build_type } @$build_tasks ) {
			confess "Cannot remove_duplicate_build_tasks() for ProfileBuildTasks with inconsistent compass_profile_build_type()s";
		}
		if ( any { ! $ARG->dir_set()->is_equal_to( $dir_set ) } @$build_tasks ) {
			confess "Cannot remove_duplicate_build_tasks() for ProfileBuildTasks with inconsistent dir_set()s";
		}

		my %prev_seen_ids;
		foreach my $build_task ( @$build_tasks ) {

			my $starting_cluster_lists = $build_task->starting_cluster_lists();
			my @del_indices = grep {

				my $id                = id_of_starting_clusters( $starting_cluster_lists->[ $ARG ] );
				my $prev_seen         = $prev_seen_ids{ $id };
				$prev_seen_ids{ $id } = 1;
				$prev_seen;
			} ( 0 .. $#$starting_cluster_lists );

			foreach my $reverse_index ( reverse( @del_indices ) ) {
				splice( @$starting_cluster_lists, $reverse_index, 1 );
			}
		}
	}

	return $build_tasks;
}

=head2 estimate_time_to_execute_step_of_index

TODOCUMENT

# TODO: Make this estimate time more sensibly than assuming 1 second per profile step

=cut

sub estimate_time_to_execute_step_of_index {
	my ( $self, $index ) = @ARG;
	my $step = $self->step_of_index( $index );
	return Time::Seconds->new( 1 );
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
		profile_tasks => [
			$self->$_clone(
				starting_cluster_lists => [ @{ $self->starting_cluster_lists() } [ $start_index .. ( $start_index + $num_steps - 1 ) ] ]
			)
		],

	);
}

1;
