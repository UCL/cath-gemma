package Cath::Gemma::Tree::Merge;

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars          /;
use List::Util         qw/ max                     /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile                 /;
use Types::Standard    qw/ Num Object Optional Str /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaTreeMerge
/;
use Cath::Gemma::Util;

=head2 mergee_a

TODOCUMENT

=cut


=head2 mergee_b

TODOCUMENT

=cut


has [ qw/ mergee_a mergee_b / ] => (
	is => 'ro',
	isa => Str|CathGemmaTreeMerge,
);

=head2 score

TODOCUMENT

=cut

has score => (
	is  => 'rw',
	isa => Num,
);

=head2 score_with_lower_bound

TODOCUMENT

=cut

sub score_with_lower_bound {
	state $check = compile( Object, Optional[Num] );
	my ( $self, $lower_bound ) = $check->( @ARG );

	return max( $self->score(), ( $lower_bound // 1e-300 ) );
}

=head2 mergee_a_is_starting_cluster

TODOCUMENT

=cut

sub mergee_a_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_a() );
}

=head2 mergee_a_id

TODOCUMENT

=cut

sub mergee_a_id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	return $self->mergee_a_is_starting_cluster()
		? $self->mergee_a()
		: $self->mergee_a()->id( $clusts_ordering );
}

=head2 mergee_b_is_starting_cluster

TODOCUMENT

=cut

sub mergee_b_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_b() );
}

=head2 mergee_b_id

TODOCUMENT

=cut

sub mergee_b_id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	return $self->mergee_b_is_starting_cluster()
		? $self->mergee_b()
		: $self->mergee_b()->id( $clusts_ordering );
}

=head2 starting_clusters_a

TODOCUMENT

=cut

sub starting_clusters_a {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	no warnings 'recursion';

	$clusts_ordering //= 'simple_ordering';

	return $self->mergee_a_is_starting_cluster()
		? [ $self->mergee_a() ]
		: $self->mergee_a()->starting_nodes( $clusts_ordering )
}

=head2 starting_clusters_b

TODOCUMENT

=cut

sub starting_clusters_b {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	no warnings 'recursion';

	$clusts_ordering //= 'simple_ordering';

	return $self->mergee_b_is_starting_cluster()
		? [ $self->mergee_b() ]
		: $self->mergee_b()->starting_nodes( $clusts_ordering )
}

=head2 starting_nodes

TODOCUMENT

=cut

sub starting_nodes {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	# confess ' ';
	no warnings 'recursion';

	return
		( $clusts_ordering eq 'tree_df_ordering' )
		? [
			@{ $self->starting_clusters_a( $clusts_ordering ); },
			@{ $self->starting_clusters_b( $clusts_ordering ); },
		]
		: [
			cluster_name_spaceship_sort( @{ $self->starting_nodes( 'tree_df_ordering' ) } )
		];
}

=head2 id

TODOCUMENT

=cut

sub id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	return id_of_starting_clusters( $self->starting_nodes( $clusts_ordering ) );
}

1;
