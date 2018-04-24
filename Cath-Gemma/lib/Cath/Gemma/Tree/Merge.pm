package Cath::Gemma::Tree::Merge;

=head1 NAME

Cath::Gemma::Tree::Merge - The data associated with a single Merge in a MergeList (ie in a tree)

This may refer to other Merges so may not be very meaningful outside of the context of a MergeList

=cut

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
use Types::Standard    qw/ LaxNum Object Optional Str /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaTreeMerge
/;
use Cath::Gemma::Util;

=head2 mergee_a

The first item in this Merge

This may either be the ID of a starting cluster or a reference to another Merge node

=cut


=head2 mergee_b

The second item in this Merge

This may either be the ID of a starting cluster or a reference to another Merge node

=cut


has [ qw/ mergee_a mergee_b / ] => (
	is => 'ro',
	isa => Str|CathGemmaTreeMerge,
);

=head2 score

The score associated with this merge

This will typically be of the form of an evalue (ie >= 0; smaller is better)

=cut

has score => (
	is  => 'rw',
	isa => LaxNum,
);

=head2 score_with_lower_bound

Get the score associated with this Merge bounded by the optionally specified lower bound or 1e-300

=cut

sub score_with_lower_bound {
	state $check = compile( Object, Optional[LaxNum] );
	my ( $self, $lower_bound ) = $check->( @ARG );

	return max( $self->score(), ( $lower_bound // 1e-300 ) );
}

=head2 mergee_a_is_starting_cluster

Whether the first mergee is a starting cluster (as opposed to a merge node)

=cut

sub mergee_a_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_a() );
}

=head2 mergee_a_id

Return an ID for the first mergee, using the optionally-specified ordering
to construct the ID if the first mergee is itself a merge node.

If the first mergee is a starting cluster, this is just the starting cluster ID;
otherwise it's an ID using the optionally-specified ordering.

=cut

sub mergee_a_id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= default_clusts_ordering();

	return $self->mergee_a_is_starting_cluster()
		? $self->mergee_a()
		: $self->mergee_a()->id( $clusts_ordering );
}

=head2 mergee_b_is_starting_cluster

Whether the second mergee is a starting cluster (as opposed to a merge node)

=cut

sub mergee_b_is_starting_cluster {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return mergee_is_starting_cluster( $self->mergee_b() );
}

=head2 mergee_b_id

Return an ID for the second mergee, using the optionally-specified ordering
to construct the ID if the second mergee is itself a merge node.

If the second mergee is a starting cluster, this is just the starting cluster ID;
otherwise it's an ID using the optionally-specified ordering.

=cut

sub mergee_b_id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= default_clusts_ordering();

	return $self->mergee_b_is_starting_cluster()
		? $self->mergee_b()
		: $self->mergee_b()->id( $clusts_ordering );
}

=head2 starting_clusters_a

Return the list of starting clusters involved in the first mergee
using the optionally-specified ordering

=cut

sub starting_clusters_a {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	no warnings 'recursion';

	$clusts_ordering //= default_clusts_ordering();

	return $self->mergee_a_is_starting_cluster()
		? [ $self->mergee_a() ]
		: $self->mergee_a()->starting_nodes( $clusts_ordering )
}

=head2 starting_clusters_b

Return the list of starting clusters involved in the second mergee
using the optionally-specified ordering

=cut

sub starting_clusters_b {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	no warnings 'recursion';

	$clusts_ordering //= default_clusts_ordering();

	return $self->mergee_b_is_starting_cluster()
		? [ $self->mergee_b() ]
		: $self->mergee_b()->starting_nodes( $clusts_ordering )
}

=head2 starting_nodes

Return the list of starting clusters involved in the merge
using the optionally-specified ordering

=cut

sub starting_nodes {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= default_clusts_ordering();

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

Get the ID for this merge using the optionally-specified ordering

=cut

sub id {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= default_clusts_ordering();

	return id_of_clusters( $self->starting_nodes( $clusts_ordering ) );
}

1;
