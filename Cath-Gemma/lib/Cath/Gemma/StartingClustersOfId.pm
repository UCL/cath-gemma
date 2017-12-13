package Cath::Gemma::StartingClustersOfId;

use strict;
use warnings;

# Core
# use List::Util         qw/ max maxstr min minstr sum                            /;
# use POSIX              qw/ log10                                                /;
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
# use List::MoreUtils    qw/ first_value                                          /;
# use Types::Standard    qw/ Num Tuple slurpy                                     /;
use Type::Params       qw/ compile                                              /;
use Types::Standard    qw/ ArrayRef ClassName HashRef Object Optional Str Tuple /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaScanScansData
/;
# 	CathGemmaScanScanData
# /;
use Cath::Gemma::Util;

=head2 starting_clusters_of_ids

TODOCUMENT

At present there is no invariant that each array of starting clusters is sorted

=cut

has _scoi => (
	is          => 'rwp',
	isa         => HashRef[ArrayRef[Str]],
	handles_via => 'Hash',
	handles     => {
		contains => 'exists',
		count    => 'count',
	# 	is_empty => 'is_empty',
	# 	ids      => 'keys',
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
	$id //= id_of_starting_clusters( $starting_clusters );
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
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	splice( @ARG, 0, 3 );

	my $starting_clusters_1 = $self->remove_id( $id1 );
	my $starting_clusters_2 = $self->remove_id( $id2 );

	return combine_starting_cluster_names( $starting_clusters_1, $starting_clusters_2, @ARG );
}

=head2 merge_pair

TODOCUMENT

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

TODOCUMENT

=cut

sub merge_pairs {
	state $check = compile( Object, ArrayRef[Tuple[Str, Str]], Optional[CathGemmaNodeOrdering] );
	my ( $self, $id_pairs ) = $check->( @ARG );
	splice( @ARG, 0, 2 );

	return [
		map {
			my ( $id1, $id2 ) = @$ARG;
			$self->merge_pair( $id1, $id2, @ARG );
		} @$id_pairs
	];
}

=head2 no_op_merge_pair

TODOCUMENT

=cut

sub no_op_merge_pair {
	my $self = shift @ARG;
	return dclone( $self )->merge_pair( @ARG );
}

=head2 no_op_merge_pairs

TODOCUMENT

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
