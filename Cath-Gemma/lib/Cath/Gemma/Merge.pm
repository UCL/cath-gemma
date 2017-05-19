package Cath::Gemma::Merge;

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars               /;
use v5.10;

# Moo
use Moo;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile                      /;
use Types::Standard    qw/ Bool Num Object Optional Str /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaMerge               /;
use Cath::Gemma::Util;

=head2 mergee_a

=cut

has mergee_a => (
	is => 'ro',
	isa => Str|CathGemmaMerge,
);

=head2 mergee_b

=cut

has mergee_b => (
	is => 'ro',
	isa => Str|CathGemmaMerge,
);

=head2 score

=cut

has score => (
	is  => 'ro',
	isa => Num,
);

=head2 mergee_a_is_starting_cluster

=cut

sub mergee_a_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_a() );
}

=head2 mergee_a_id

=cut

sub mergee_a_id {
	state $check = compile( Object, Optional[Bool] );
	my ( $self, $use_depth_first ) = $check->( @ARG );

	$use_depth_first //= 0;

	return $self->mergee_a_is_starting_cluster()
		? $self->mergee_a()
		: $self->mergee_a()->id( $use_depth_first );
}

=head2 mergee_b_is_starting_cluster

=cut

sub mergee_b_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_b() );
}

=head2 mergee_b_id

=cut

sub mergee_b_id {
	state $check = compile( Object, Optional[Bool] );
	my ( $self, $use_depth_first ) = $check->( @ARG );

	$use_depth_first //= 0;

	return $self->mergee_b_is_starting_cluster()
		? $self->mergee_b()
		: $self->mergee_b()->id( $use_depth_first );
}

=head2 starting_nodes

=cut

sub starting_nodes {
	state $check = compile( Object, Optional[Bool] );
	my ( $self, $use_depth_first ) = $check->( @ARG );

	$use_depth_first //= 0;

	return
		$use_depth_first
		? [
			(
				$self->mergee_a_is_starting_cluster()
					? $self->mergee_a()
					: @{ $self->mergee_a()->starting_nodes( 1 ) }
			),
			(
				$self->mergee_b_is_starting_cluster()
					? $self->mergee_b()
					: @{ $self->mergee_b()->starting_nodes( 1 ) }
			)
		]
		: [
			sort { cluster_name_spaceship( $a, $b ) } @{ $self->starting_nodes( 1 ) }
		];
}

=head2 id

=cut

sub id {
	state $check = compile( Object, Optional[Bool] );
	my ( $self, $use_depth_first ) = $check->( @ARG );

	$use_depth_first //= 0;

	return id_of_starting_clusters( $self->starting_nodes( $use_depth_first ) );
}

1;
