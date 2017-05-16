package Cath::Gemma::CompassProfileBuilder;

use strict;
use warnings;

# Core
use Digest::MD5 qw/ md5_hex /;

# Moo
use Moo;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Types::Standard qw/ Num Str /; 

# Cath
use Cath::Gemma::Types qw/ CathGemmaMerge /; 
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
	my $self = shift;
	return mergee_is_starting_cluster( $self->mergee_a() );
}

=head2 mergee_b_is_starting_cluster

=cut

sub mergee_b_is_starting_cluster {
	my $self = shift;
	return mergee_is_starting_cluster( $self->mergee_b() );
}

=head2 starting_nodes_in_depth_first_traversal_order

=cut

sub starting_nodes_in_depth_first_traversal_order {
	my $self = shift;

	return [
		(
			$self->mergee_a_is_starting_cluster()
				? $self->mergee_a()
				: @{ $self->mergee_a()->starting_nodes_in_depth_first_traversal_order() }
		),
		(
			$self->mergee_b_is_starting_cluster()
				? $self->mergee_b()
				: @{ $self->mergee_b()->starting_nodes_in_depth_first_traversal_order() }
		)
	];
}

=head2 starting_nodes_in_standard_order

=cut

sub starting_nodes_in_standard_order {
	my $self = shift;

	return [ sort { cluster_name_spaceship( $a, $b ) } @{ $self->starting_nodes_in_depth_first_traversal_order() } ];
}

=head2 standard_order_id

=cut

sub standard_order_id {
	my $self = shift;

	my $nodes = $self->starting_nodes_in_depth_first_traversal_order();
	return md5_hex( @$nodes );
}

=head2 depth_first_traversal_id

=cut

sub depth_first_traversal_id {
	my $self = shift;

	my $nodes = $self->starting_nodes_in_standard_order();
	return md5_hex( @$nodes );
}

1;