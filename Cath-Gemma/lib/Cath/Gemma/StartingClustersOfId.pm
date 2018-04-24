package Cath::Gemma::StartingClustersOfId;

=head1 NAME

Cath::Gemma::StartingClustersOfId - For each cluster ID, store the IDs of the starting clusters that make it up

=cut

use strict;
use warnings;

# Core
use Carp               qw/ confess                                              /;
use English            qw/ -no_match_vars                                       /;
use Storable           qw/ dclone                                               /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params       qw/ compile                                              /;
use Types::Standard    qw/ ArrayRef ClassName HashRef Object Optional Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaScanScansData
/;
use Cath::Gemma::Util;

=head2 _scoi

TODOCUMENT

At present there is no invariant that each array of starting clusters is sorted

=cut

has _scoi => (
	is          => 'rwp',
	isa         => HashRef[ArrayRef[Str]],
	handles_via => 'Hash',
	handles     => {
		contains_id => 'exists',
		count       => 'count',
	},
	default     => sub { {}; },
);

=head2 sorted_ids

TODOCUMENT

=cut

sub sorted_ids {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [ cluster_name_spaceship_sort( keys( %{ $self->_scoi() } ) ) ];
}

=head2 add_separate_starting_clusters

TODOCUMENT

=cut

sub add_separate_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	foreach my $id ( @$ids ) {
		$self->add_starting_clusters_group_by_id( [ $id ] );
	}
	return $self;
}

=head2 add_starting_clusters_group_by_id

TODOCUMENT

=cut

sub add_starting_clusters_group_by_id {
	state $check = compile( Object, ArrayRef[Str], Optional[Str] );
	my ( $self, $starting_clusters, $id ) = $check->( @ARG );
	$id //= id_of_clusters( $starting_clusters );
	$self->_scoi()->{ $id } = $starting_clusters;
	return $id;
}

=head2 get_starting_clusters_of_id

TODOCUMENT

May return undef if the ID isn't recognised

TODO: Consider adding sorted_starting_clusters_of_id()

=cut

sub get_starting_clusters_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	return $self->_scoi()->{ $id };
}

=head2 remove_id

Remove the entry for the specified ID and return the starting clusters that were associated with it

Will die if the starting cluster isn't recognised

=cut

sub remove_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	my $starting_clusters = $self->_scoi()->{ $id };
	if ( ! defined( $starting_clusters ) ) {
		use Data::Dumper;
		warn Dumper( {
			StartingClustersOfId__remove_id__dclone_self => dclone( $self ),
		} ) . ' ';

		confess "Unable to remove unrecognised cluster ID \"$id\"";
	}

	delete $self->_scoi()->{ $id };
	return $starting_clusters;
}

=head2 merge_remove

TODOCUMENT

=cut

sub merge_remove {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $cluster_id1, $cluster_id2, @clusts_ordering ) = $check->( @ARG );

	my $starting_clusters_1 = $self->remove_id( $cluster_id1 );
	my $starting_clusters_2 = $self->remove_id( $cluster_id2 );

	return combine_starting_cluster_names( $starting_clusters_1, $starting_clusters_2, @clusts_ordering );
}

=head2 merge_pair

Merge the two clusters with the specified IDs using the optionally specified
cluster ordering (or default_clusts_ordering()) and return:

[
	the ID of the new merged cluster,
	the starting clusters within the new merged cluster,
	the other IDs that aren't being merged in this operation
]

=cut

sub merge_pair {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	$check->( @ARG );
	my $self = shift @ARG;

	my $merged_starting_clusters = $self->merge_remove( @ARG );
	my $other_ids                = $self->sorted_ids();
	my $merged_node_id           = $self->add_starting_clusters_group_by_id( $merged_starting_clusters );
	return [
		$merged_node_id,
		$merged_starting_clusters,
		$other_ids,
	];
}

=head2 merge_pairs

Merge the specified list of pairs of clusters (in order in which they appear) using
the optionally specified cluster ordering (or default_clusts_ordering()) and an ref-to-array
of entries corresponding to the merges like:

[
	the ID of the new merged cluster,
	the starting clusters within the new merged cluster,
	the other IDs that aren't being merged in this operation
]

=cut

sub merge_pairs {
	state $check = compile( Object, ArrayRef[Tuple[Str, Str]], Optional[CathGemmaNodeOrdering] );
	my ( $self, $id_pairs, @clusts_ordering ) = $check->( @ARG );

	return [
		map {
			my ( $id1, $id2 ) = @$ARG;
			$self->merge_pair( $id1, $id2, @clusts_ordering );
		} @$id_pairs
	];
}

=head2 no_op_merge_pair

Dry-run version of merge_pair(): perform a *dry-run* merge of the two clusters with
the specified IDs using the optionally specified cluster ordering (or default_clusts_ordering())
and return:

[
	the ID of the new merged cluster,
	the starting clusters within the new merged cluster,
	the other IDs that aren't being merged in this operation
]


=cut

sub no_op_merge_pair {
	my $self = shift @ARG;
	return dclone( $self )->merge_pair( @ARG );
}

=head2 no_op_merge_pairs

Dry-run version of merge_pairs(): perform a *dry-run* merge of the specified list of
pairs of clusters (in order in which they appear) using the optionally specified
cluster ordering (or default_clusts_ordering()) and an ref-to-array of entries corresponding to
the merges like:

[
	the ID of the new merged cluster,
	the starting clusters within the new merged cluster,
	the other IDs that aren't being merged in this operation
]

=cut

sub no_op_merge_pairs {
	my $self = shift @ARG;
	return dclone( $self )->merge_pairs( @ARG );
}

=head2 new_from_starting_clusters

TODOCUMENT

=cut

sub new_from_starting_clusters {
	state $check = compile( ClassName, ArrayRef[Str] );
	my ( $class, $ids ) = $check->( @ARG );

	my $new = $class->new();
	$new->add_separate_starting_clusters( $ids );
	return $new;
}

1;
