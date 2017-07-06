package Cath::Gemma::Compute::WorkBatchList;

=head1 NAME

Cath::Gemma::Compute::WorkBatchList - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp               qw/ confess             /;
use English            qw/ -no_match_vars      /;
use List::Util         qw/ min                 /;
use Storable           qw/ dclone              /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Array::Utils       qw/ intersect           /;
use Type::Params       qw/ compile Invocant    /;
use Types::Standard    qw/ ArrayRef Int Object /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatch
	/;
use Cath::Gemma::Util;

=head2 batches

=cut

has batches => (
	is  => 'ro',
	is  => 'rwp',
	isa => ArrayRef[CathGemmaComputeWorkBatch],
	handles_via => 'Array',
	handles     => {
		batch_of_index => 'get',
		num_batches    => 'count',
		is_empty       => 'is_empty',
		# push           => 'push',
	}
);

=head2 dependencies

This may be shorter than batches so prefer accessing through get_dependency_of_index()

The elements correspond to the elements of batches. Each is a (possibly empty) array
of strictly-positive integers, indicating the other batches on which the batch depends
as the number of steps prior each of those batches.

eg, an entry [ 3, 5 ] means that the corresponding batch depends on the batches that
appear 3 and 5 positions earlier respectively batches

=cut

has dependencies => (
	is      => 'ro',
	isa     => ArrayRef[ArrayRef[Int]],
	default => sub { [ ]; },
	handles_via => 'Array',
	handles     => {
		num_dependencies   => 'count',
		dependencies_empty => 'is_empty',
	}
);

=head2 get_dependency_of_index

=cut

sub get_dependency_of_index {
	state $check = compile( Object, Int );
	my ( $self, $index ) = $check->( @ARG );

	if ( $index < 0 ) {
		confess 'get_dependency_of_index() was called with a negative index ' . $index;
	}
	return ( $index < $self->num_dependencies() )
		? $self->dependencies()->[ $index ]
		: [];
}

=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return generic_id_of_clusters( [ map { $ARG->id() } @{ $self->batches() } ] );
}

=head2 _init_tidy_dependencies

=cut

sub _init_tidy_dependencies {
	state $check = compile( Invocant, ArrayRef[ArrayRef[Int]], Int );
	my ( $proto, $data, $count ) = $check->( @ARG );

	$data = dclone( $data );

	foreach my $ctr ( 0 .. $#$data ) {
		if ( ! defined( $data->[ $ctr ] ) ) {
			$data->[ $ctr ] = [];
		}
		foreach my $value ( @{ $data->[ $ctr ] } ) {
			$value = ( $ctr - $value );
		}
		@{ $data->[ $ctr ] } = sort { $a <=> $b } @{ $data->[ $ctr ] };
	}


	foreach my $ctr ( 0 .. $#$data ) {
		foreach my $value ( @{ $data->[ $ctr ] } ) {
			if ( $value < 0 ) {
				confess "Dependencies have become inconsistent with value $value at position $ctr";
			}
		}
	}
	return $data;
}

=head2 _group_tidy_dependencies

=cut

sub _group_tidy_dependencies {
	state $check = compile( Invocant, ArrayRef[ArrayRef[Int]] );
	my ( $proto, $data ) = $check->( @ARG );

	my %always_withs;
	foreach my $datum ( @$data ) {
		foreach my $value ( @$datum ) {
			my %others = ( map { ( $ARG, 1 ) } grep { $ARG != $value } sort { $a <=> $b } @$datum );
			if ( ! defined( $always_withs{ $value } ) ) {
				foreach my $other_value ( sort { $a <=> $b } keys ( %others ) ) {
					if ( ! defined( $always_withs{ $other_value } ) || defined( $always_withs{ $other_value }->{ $value } ) ) {
						$always_withs{ $value }->{ $other_value } = 1;
					}
				}
			}
			else {
				my @links_to_break = grep { ! $others{ $ARG } } sort { $a <=> $b } keys( %{ $always_withs{ $value } } );
				foreach my $link_to_break ( @links_to_break ) {
					delete $always_withs{ $value         }->{ $link_to_break };
					delete $always_withs{ $link_to_break }->{ $value         };
				}
			}
		}
	}

	my @frees_group = (
		grep
		{ ( scalar( @{ $data->[ $ARG ] } ) == 0 ) && ! defined( $always_withs{ $ARG } ) }
		( 0 .. $#$data )
	);

	my @depped_on_groups

	my @groups = (
		\@frees_group,
		map
			{ [ sort { $a <=> $b } ( $ARG, map { $ARG + 0; } keys( %{ $always_withs{ $ARG } } ) ) ]; }
		grep
			{ $ARG < min( keys( %{ $always_withs{ $ARG } } ) ) }
			sort { $a <=> $b } keys( %always_withs )
	);
	@groups = sort { $a->[ 0 ] <=> $b->[ 0 ] } @groups;

	use Carp qw/ confess /;
	use Data::Dumper;

	confess Dumper( [ \%always_withs, \@groups ] );
}

# =head2 id

# =cut

# sub id {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );

# 	return generic_id_of_clusters( [ map { $ARG->id() } @{ $self->profile_tasks() } ] );
# }

# =head2 num_profiles

# =cut

# sub num_profiles {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return sum0( map { $ARG->num_profiles(); } @{ $self->profile_tasks() } );
# }

# =head2 total_num_starting_clusters_in_profiles

# =cut

# sub total_num_starting_clusters_in_profiles {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );
# 	return sum0( map { $ARG->total_num_starting_clusters(); } @{ $self->profile_tasks() } );
# }

# =head2 execute_task

# =cut

# sub execute_task {
# 	state $check = compile( Object, CathGemmaDiskExecutables );
# 	my ( $self, $exes ) = $check->( @ARG );

# 	my @results;
# 	foreach my $profile_task ( @{ $self->profile_tasks() } ) {
# 		push @results, $profile_task->execute_task( $exes );
# 	}
# 	return \@results;
# }

# =head2 write_to_file

# =cut

# sub write_to_file {
# 	state $check = compile( Object, Path );
# 	my ( $self, $file ) = $check->( @ARG );
# 	$file->spew( freeze( $self ) );
# }

# =head2 read_from_file

# =cut

# sub read_from_file {
# 	state $check = compile( Invocant, Path );
# 	my ( $proto, $file ) = $check->( @ARG );

# 	return thaw( $file->slurp() );
# }

# =head2 execute_from_file

# =cut

# sub execute_from_file {
# 	state $check = compile( Invocant, Path, CathGemmaDiskExecutables );
# 	my ( $proto, $file, $exes ) = $check->( @ARG );

# 	return $proto->read_from_file( $file )->execute_task( $exes );
# }

1;
