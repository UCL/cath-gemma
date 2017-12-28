package Cath::Gemma::Scan::Impl::Links;

use strict;
use warnings;

# Core
use List::Util          qw/ first min                                                                  /;
use Carp                qw/ confess                                                                    /;
use English             qw/ -no_match_vars                                                             /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils     qw/ bsearch uniq                                                               /;
use List::UtilsBy       qw/ min_by                                                                     /;
use Type::Params        qw/ compile                                                                    /;
use Types::Standard     qw/ ArrayRef ClassName CodeRef HashRef Int Maybe Num Object Optional Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Util;

=head2 _id_of_index

TODOCUMENT

=cut

has _id_of_index => (
	is          => 'rwp',
	isa         => ArrayRef[Maybe[Str]],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_get_id_of_index  => 'get',
		_num_indices      => 'count',
		_push_id_of_index => 'push',
		_set_id_of_index  => 'set',
	},
);

=head2 _index_of_id

TODOCUMENT

=cut

has _index_of_id => (
	is          => 'rwp',
	isa         => HashRef[Num],
	default     => sub { {}; },
	handles_via => 'Hash',
	handles     => {
		_contains_index_of_id => 'exists',
		_delete_index_of_id   => 'delete',
		_get_index_of_id      => 'get',
		_set_index_of_id      => 'set',
		count                 => 'count',
		ids                   => 'keys',
	},
);

=head2 _links_data

TODOCUMENT

=cut

has _links_data => (
	is          => 'rwp',
	isa         => ArrayRef[ArrayRef[Tuple[Int,Num]]],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_get_links_data => 'get',
		_set_links_data => 'set',
	},
);

=head2 _checked_index_of_id

TODOCUMENT

=cut

sub _checked_index_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	if ( ! $self->_contains_index_of_id( $id ) ) {
		confess 'Unable to find an index associated with the ID "' . $id . '"';
	}
	return $self->_get_index_of_id( $id );
}

=head2 _ensure_index_of_id

TODOCUMENT

=cut


sub _ensure_index_of_id {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	if ( ! $self->_contains_index_of_id( $id ) ) {
		my $new_index = $self->_num_indices();
		$self->_set_index_of_id ( $id, $new_index );
		$self->_push_id_of_index( $id             );
		$self->_set_links_data  ( $new_index, []  );
	}
	return $self->_get_index_of_id( $id );
}

=head2 get_score_between

TODOCUMENT

=cut

sub get_score_between {
	state $check = compile( Object, Str, Str );
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	my $index1        = $self->_checked_index_of_id( $id1 );
	my $index2        = $self->_checked_index_of_id( $id2 );
	my $index_1_links = $self->_get_links_data( $index1 );
	my $link          = first { $ARG->[ 0 ] == $index2 } ( @$index_1_links );

	return defined( $link ) ? $link->[ -1 ] : undef;
}

=head2 sorted_ids

TODOCUMENT

=cut

sub sorted_ids {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [ cluster_name_spaceship_sort( $self->ids() ) ];
}

=head2 add_separate_starting_clusters

TODOCUMENT

=cut

sub add_separate_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	foreach my $id ( @$ids ) {
		$self->_ensure_index_of_id( $id );
	}
	return $self;
}

=head2 add_scan_entry

TODOCUMENT

This doesn't check whether a link has already been added between the specified items
so don't add the same link multiple times

=cut

sub add_scan_entry {
	state $check = compile( Object, Str, Str, Num );
	my ( $self, $id1, $id2, $score ) = $check->( @ARG );

	my $index1 = $self->_ensure_index_of_id( $id1 );
	my $index2 = $self->_ensure_index_of_id( $id2 );

	my $the_links_data1 = $self->_get_links_data( $index1 );
	my $the_links_data2 = $self->_get_links_data( $index2 );
	push @$the_links_data1, [ $index2, $score ];
	push @$the_links_data2, [ $index1, $score ];
	return $self;
}

=head2 remove

TODOCUMENT

=cut

sub remove {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	my $index = $self->_checked_index_of_id( $id );
	$self->_set_id_of_index   ( $index, undef );
	$self->_set_links_data    ( $index, undef );
	$self->_delete_index_of_id( $id           );
	return $self;
}

=head2 merge_pair

TODOCUMENT

=cut

sub merge_pair {
	state $check = compile( Object, Str, Str, Str, CodeRef );
	my ( $self, $merged_node_id, $id1, $id2, $score_update_function ) = $check->( @ARG );

	my $index1 = $self->_checked_index_of_id( $id1 );
	my $index2 = $self->_checked_index_of_id( $id2 );

	my $get_other_scores = sub {
		my $index = shift;
		my @other_scores;
		$other_scores[ $self->_num_indices() ] = undef;
		shift @other_scores;
		foreach my $link ( @{ $self->_get_links_data( $index ) } ) {
			my ( $other_index, $other_score ) = @$link;
			@other_scores[ $other_index ] = $other_score;
		}
		return \@other_scores;
	};
	my $other_scores1 = $get_other_scores->( $index1 );
	my $other_scores2 = $get_other_scores->( $index2 );

	#
	my @new_clust_scores = grep {
		defined( $ARG->[ 1 ] )
	}
	map {
		my $other_idx    = $ARG;
		my $other_score1 = $other_scores1->[ $other_idx ];
		my $other_score2 = $other_scores2->[ $other_idx ];
		[
			$other_idx,
			$score_update_function->(
				$other_score1,
				$other_score2,
				$self->_get_id_of_index( $other_idx )
			)
		];
	}
	grep {
		(
			( $ARG != $index1 )
			&&
			( $ARG != $index2 )
			&&
			defined( $self->_get_id_of_index( $ARG ) )
		);
	} ( 0..$#$other_scores1 );

	my $index = $self->_ensure_index_of_id( $merged_node_id );
	$self->_set_links_data( $index, \@new_clust_scores );
	foreach my $new_clust_score ( @new_clust_scores ) {
		my ( $other_index, $other_score ) = @$new_clust_score;
		push @{ $self->_get_links_data( $other_index ) }, [ $index, $other_score ];
	}

	$self->remove( $id1 );
	$self->remove( $id2 );

	return $self;
}

=head2 get_id_and_score_of_lowest_score_of_id

TODOCUMENT

=cut

sub get_id_and_score_of_lowest_score_of_id {
	state $check = compile( Object, Str, Optional[HashRef] );
	my ( $self, $id, $excluded_ids ) = $check->( @ARG );

	$excluded_ids //= {};
	my @excluded_indices = sort { $a <=> $b } map { $self->_get_index_of_id( $ARG ); } keys( %$excluded_ids );

	if ( $self->count() < 2 ) {
		use Data::Dumper;
		confess 'Cannot get ID and score of lowest score of ID when there are fewer than two items that are linked ' . Dumper( $self ) . ' ';
	}

	my $index       = $self->_get_index_of_id( $id );
	my $links_of_id = $self->_get_links_data( $index );

	# It would be better if this were full deterministic (ie deterministically chose
	# the same index amongst several with the same best score)
	my $best_link_index = min_by {
		$links_of_id->[ $ARG ]->[ -1 ];
	}
	grep {
		my $other_idx         = $links_of_id->[ $ARG ]->[ 0 ];
		my $index_is_active   = defined( $self->_get_id_of_index( $other_idx ) );
		my $index_is_excluded = bsearch { $ARG <=> $other_idx } @excluded_indices;

		( $index_is_active && ! $index_is_excluded );
	} ( 0 .. $#$links_of_id );

	if ( ! defined( $best_link_index ) ) {
		return [ undef, 'inf' ];
	}

	my ( $best_index, $best_score ) = @{ $links_of_id->[ $best_link_index ] };
	my $best_id = $self->_get_id_of_index( $best_index );

	return [
		$best_id,
		$best_score
	];
}

=head2 new_from_score_of_id_of_id

TODOCUMENT

=cut

sub new_from_score_of_id_of_id {
	state $check = compile( ClassName, HashRef[HashRef[Num]] );
	my ( $class, $data ) = $check->( @ARG );

	my $new = $class->new();
	foreach my $id1 ( sort( keys( %$data ) ) ) {
		my $data_of_id1 = $data->{ $id1 };
		foreach my $id2 ( sort( keys( %$data_of_id1 ) ) ) {
			if ( $id1 lt $id2 || ! defined( $data->{ $id2 }->{ $id1 } ) ) {
				$new->add_scan_entry( $id1, $id2, $data_of_id1->{ $id2 } );
			}
		}
	}
	return $new;
}

1;
