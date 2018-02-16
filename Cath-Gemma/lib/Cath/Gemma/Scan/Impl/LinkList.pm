package Cath::Gemma::Scan::Impl::LinkList;

=head1 NAME

Cath::Gemma::Scan::Impl::LinkList - [For use in ScansData via Links] Store the links from one cluster to another

TODOCUMENT - how the actives work (and why that makes sense because it's permanently stored in Links)

This class is fairly performance critical both in terms of CPU and, to a lesser extent, memory.

The current design is:
 * one array containing the indices
 * another array containing the corresponding scores
 * a third array of "meta-indices" indices into the first two arrays - rules:
   * sort the "meta-indices" array from best (smallest) associated score to worst
   * but do that sort array *lazily* - only when the best result is first queried
   * before the sort, just push new meta-indices on to the end
   * after the sort, keep the the meta-indices in order
 * a flat to indicate whether the meta-indices have yet been sorted

It'd be nice to use a heap data structure but none of the CPAN modules
appeared to meet all desiderata:
 * Pure Perl only
 * Allows the ordering function to be specified
 * Allows the array to be directly modified (eg so that several elements
   can be added/removed and then the heap (re)built)

An investigation of Heap::MinMax was initially promising but then
demonstrated that the build_heap() function was doing what was hoped.

=cut

use strict;
use warnings;

# Core
use Carp            qw/ confess                                                               /;
use English         qw/ -no_match_vars                                                        /;
use List::Util      qw/ first max                                                             /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
# use List::MoreUtils qw/ bsearch                                                               /;
use List::MoreUtils qw/ bsearch first_index lower_bound                                       /;
use List::UtilsBy   qw/ max_by min_by                                                         /;
use Log::Log4perl::Tiny qw/ :easy          /; # *********** TEMPORARY? ***********
use Type::Params    qw/ compile                                                               /;
use Types::Standard qw/ ArrayRef Bool ClassName CodeRef HashRef Int Num Object Optional Tuple /;

=head2 _link_indices

The index is meaningful in the context of ScansData

The elements of this are in 1-1 correspondence with the elements of _link_scores

=cut

has _link_indices => (
	is          => 'rwp',
	isa         => ArrayRef[Int],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_index_of_meta_index     => 'get',
		_push_index              => 'push',
		_set_index_of_meta_index => 'set',
	# 	# _set_link_data => 'set',
	},
);

=head2 _link_scores

TODOCUMENT Store the links from some cluster to a bunch of others

The elements of this are in 1-1 correspondence with the elements of _link_indices

=cut

has _link_scores => (
	is          => 'rwp',
	isa         => ArrayRef[Num],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_push_score              => 'push',
		_score_of_meta_index     => 'get',
		_set_score_of_meta_index => 'set',
	# 	_count    => 'count',
	# 	# _set_link_data => 'set',
	},
);

=head2 _meta_indices

TODOCUMENT Store the links from some cluster to a bunch of others

This stores the indices into the _link_indices and _link_scores arrays

=cut

has _meta_indices => (
	is          => 'rwp',
	isa         => ArrayRef[Int],
	default     => sub { []; },
	handles_via => 'Array',
	handles     => {
		_get_meta_index        => 'get',
		_meta_indices_count    => 'count',
		_meta_indices_is_empty => 'is_empty',
		_push_meta_index       => 'push',
	# 	# _set_link_data => 'set',
	},
);

=head2 _meta_indices_are_sorted

Whether the _meta_indices have yet been sorted (best (ie lowest scoring) to worst (ie highest scoring))

=cut

has _meta_indices_are_sorted => (
	is          => 'rwp',
	isa         => Bool,
	default     => sub { 0; },
	handles_via => 'Bool',
	handles     => {
		_set_meta_indices_are_sorted => 'set',
	# 	mias_toggle => 'toggle',
	# 	mias_unset  => 'unset',
	},
);

# =head2 _has_been_structured

# TODOCUMENT

# =cut

# has _has_been_structured => (
# 	is      => 'rwp',
# 	isa     => Bool,
# 	default => sub { false; },
# );

# =head2 _xmax_index

# TODOCUMENT

# =cut

# has _xmax_index => (
# 	is      => 'rwp',
# 	isa     => Int,
# 	builder => '_build__xmax_index',
# );

# # =head2 _max_index_of_meta_index_bests

# # TODOCUMENT

# # TODO: Remove this?

# # =cut

# # sub _max_index_of_meta_index_bests {
# # 	state $check = compile( Object );
# # 	my ( $self ) = $check->( @ARG );

# # 	return max( map { $self->_index_of_meta_index( $ARG ); } @{ $self->_meta_index_bests() } )
# # 	       // 0;
# # }

# # =head2 _max_index_of_meta_index_heap

# # TODOCUMENT

# # TODO: Remove this?

# # =cut

# # sub _max_index_of_meta_index_heap {
# # 	state $check = compile( Object );
# # 	my ( $self ) = $check->( @ARG );

# # 	return max( map { $self->_index_of_meta_index( $ARG ); } @{ $self->_meta_index_heap() } )
# # 	       // 0;
# # }

# =head2 _build_xmax_index

# TODOCUMENT

# =cut

# sub _build__xmax_index {
# 	state $check = compile( Object );
# 	my ( $self ) = $check->( @ARG );

# 	return max(
# 		map { $self->_index_of_meta_index( $ARG ); } @{ $self->_meta_index_bests() },
# 		map { $self->_index_of_meta_index( $ARG ); } @{ $self->_meta_index_heap () },
# 	) // 0;
# }

=head2 get_score_to

Get to the score the specified index or undef if no such link

This runs in O(n) because it has to search through the links until the requested one is found

=cut

sub get_score_to {
	state $check = compile( Object, Int );
	my ( $self, $other_index ) = $check->( @ARG );

	my $first_meta_index = first_index {
		( defined( $ARG ) && $ARG == $other_index );
	} ( @{ $self->_link_indices() } );

	return ( $first_meta_index >= 0 )
		? $self->_link_scores()->[ $first_meta_index ]
		: undef;
}

=head2 remove_inactives

Remove any of the meta-indices that either refer to a now-removed index
or to an index that is now inactive

=cut

sub _remove_inactive_meta_indices {
	state $check = compile( Object, ArrayRef );
	my ( $self, $actives ) = $check->( @ARG );

	my $meta_indices = $self->_meta_indices();
	my @inactive_meta_indices = grep {
		my $meta_index = $meta_indices->[ $ARG ];
		if ( ! defined( $meta_index ) ) {
			confess 'Undefined meta-index in LinkList::_remove_inactive_meta_indices() at (meta-meta-) index ' . $ARG;
		}
		my $index     = $self->_index_of_meta_index( $meta_index );
		my $is_active = defined( $index ) && $actives->[ $index ];
		if ( defined( $index ) && ! $is_active ) {
			$self->_set_index_of_meta_index( $meta_index, undef );
			$self->_set_score_of_meta_index( $meta_index, undef );
		}
		( ! $is_active );
	} ( 0 .. $#$meta_indices );

	foreach my $reverse_index ( reverse( @inactive_meta_indices ) ) {
		splice( @$meta_indices, $reverse_index, 1 );
	}

}

=head2 add_scan_entry

Add a scan entry to the specified index with the specified score

This doesn't check whether a link has already been added between the specified items
so don't add the same link multiple times

=cut

sub add_scan_entry {
	state $check = compile( Object, Int, Num );
	my ( $self, $other_index, $score ) = $check->( @ARG );

	my $num_indices = $self->_push_index( $other_index );
	my $num_scores  = $self->_push_score( $score       );

	# Sanity check that the number of scores and number of indices match
	if ( $num_indices != $num_scores || $num_indices <= 0 ) {
		use Carp qw/ confess /;
		confess 'Internal contradiction in LinkList between the number of scores and the number indices';
	}
	my $new_meta_index = $num_indices - 1;

	# If the meta-indices have been sorted (as indicated by _meta_indices_are_sorted() being true),
	# then the order must be preserved so insert the new meta-index in the correct place
	if ( $self->_meta_indices_are_sorted() ) {

		my $correct_index = lower_bound {
			my $meta_index = $ARG;
			( $self->_score_of_meta_index( $meta_index ) <=> $score       )
			||
			( $self->_index_of_meta_index( $meta_index ) <=> $other_index )
		} @{ $self->_meta_index_bests() };
		splice @{ $self->_meta_indices() }, $correct_index, 0, $new_meta_index;
	}
	# Otherwise just stick the new meta-index at the back of the _meta_index_heap
	else {
		$self->_push_meta_index( $new_meta_index );
	}

	# Return $self to allow chaining
	return $self;
}

=head2 get_laid_out_scores

Get an array of (at least) the specified size with all the links' scores laid out
in the position of their destination index and undef in all other positions

Eg, links: [ [ 2, 75.9 ], [ 4, 22.1 ] ] would be laid out as: [ undef, undef, 75.9, undef, 22.1 ]

This is useful for when merging two clusters for efficiently combining their scores to other nodes

=cut

sub get_laid_out_scores {
	state $check = compile( Object, Int );
	my ( $self, $size ) = $check->( @ARG );

	my @other_scores = ( ( undef ) x $size );

	my $link_indices = $self->_link_indices();
	foreach my $link_index_ctr ( 0 .. $#$link_indices ) {
		my $index = $self->_index_of_meta_index( $link_index_ctr );
		my $score = $self->_score_of_meta_index( $link_index_ctr );
		if ( defined( $index ) ) {
			$other_scores[ $index ] = $score;
		}
	}
	return \@other_scores;
}

=head2 get_idx_and_score_of_lowest_score_of_id

Get the index and score of the link with lowest score
that's active and not excluded according to the specified data

The actives are specified as an array that contains a defined value
in each position that's active and an undef in all others

Post-conditions

 TODOCUMENT - BUT WON'T CHANGE STUFF !!!!!!!!!!!!!!
 * Either there will be no results left or
   the best result will be first and it will be active

=cut

sub get_idx_and_score_of_lowest_score_of_id {
	state $check = compile( Object, ArrayRef );
	my ( $self, $actives ) = $check->( @ARG );

	my $recently_removed_inactive = 0;


	if ( ! $self->_meta_indices_are_sorted() ) {

		# Remove any inactive meta-indices
		$self->_remove_inactive_meta_indices( $actives );

		# If there are some meta-indices remaining, then sort them and set the sorted flag
		if ( ! $self->_meta_indices_is_empty() ) {
			@{ $self->_meta_indices() } = sort {
				( $self->_score_of_meta_index( $a ) <=> $self->_score_of_meta_index( $b ) )
				||
				( $self->_index_of_meta_index( $a ) <=> $self->_index_of_meta_index( $b ) )
			} @{ $self->_meta_indices() };

			$self->_set_meta_indices_are_sorted();
		}
	}

	# If there's a first meta-index, but it isn't active, then remove any inactive meta-indices
	if ( ! $self->_meta_indices_is_empty() ) {
		my $first_meta_index = $self->_get_meta_index( 0 );
		if ( ! defined( $first_meta_index ) ) {
			confess 'Undefined meta-index in LinkList::get_idx_and_score_of_lowest_score_of_id() at (meta-meta-) index 0';
		}
		my $index     = $self->_index_of_meta_index( $first_meta_index );
		if ( ! defined( $index ) || ! $actives->[ $index ] ) {
			$self->_remove_inactive_meta_indices( $actives );
		}
	}

	# If there are no meta-indices, just return a null result
	if ( $self->_meta_indices_is_empty() ) {
		return [ undef, 'inf' ];
	}

	# Otherwise there are meta-indices, they're all valid, and they're sorted
	# so just return the index and score of the first (best)
	my $first_meta_index = $self->_get_meta_index( 0 );
	return [
		$self->_index_of_meta_index( $first_meta_index ),
		$self->_score_of_meta_index( $first_meta_index ),
	];
}

=head2 all_index_and_score_results_below_eq_cutoff

TODOCUMENT

=cut

sub all_index_and_score_results_below_eq_cutoff {
	state $check = compile( Object, ArrayRef, Num );
	my ( $self, $actives, $cutoff ) = $check->( @ARG );

	return [ map {
		[
			$self->_index_of_meta_index( $ARG ),
			$self->_score_of_meta_index( $ARG ),
		];
	} grep {
		my $index = $self->_index_of_meta_index( $ARG );
		my $score = $self->_score_of_meta_index( $ARG );

		(
			defined( $index )
			&&
			defined( $actives->[ $index ] )
			&&
			$score <= $cutoff
		);
	} @{ $self->_meta_indices() } ];
}

=head2 make_list

Make a LinkList of the specified array of arrays of index and score

=cut

sub make_list {
	state $check = compile( ClassName, ArrayRef[Tuple[Int,Num]] );
	my ( $class, $data ) = $check->( @ARG );

	my $result = $class->new();
	foreach my $datum ( @$data ) {
		$result->add_scan_entry( @$datum );
	}

	return $result;
}

1;
