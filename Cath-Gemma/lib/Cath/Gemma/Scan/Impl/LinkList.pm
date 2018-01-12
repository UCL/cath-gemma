package Cath::Gemma::Scan::Impl::LinkList;

use strict;
use warnings;

# Core
use English         qw/ -no_match_vars                                                   /;
use List::Util      qw/ first                                                            /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils qw/ bsearch                                                          /;
use List::UtilsBy   qw/ min_by                                                           /;
use Type::Params    qw/ compile                                                          /;
use Types::Standard qw/ ArrayRef ClassName CodeRef HashRef Int Num Object Optional Tuple /;

=head2 _links_data

Store the links from some cluster to a bunch of others

Each link is stored as an array containing the index of the cluster and the score for the link

The index is meaningful in the context of ScansData

=cut

has _links_data => (
	is          => 'rwp',
	isa         => ArrayRef[Tuple[Int,Num]],
	default     => sub { []; },
	handles_via => 'Array',
	# handles     => {
	# 	_get_links_data => 'get',
	# 	_set_links_data => 'set',
	# },
);

=head2 get_score_to

Get to the score the specified index or undef if no such link

This runs in O(n) because it has to search through the links until the requested one is found

=cut

sub get_score_to {
	state $check = compile( Object, Int );
	my ( $self, $other_index ) = $check->( @ARG );

	my $link = first { $ARG->[ 0 ] == $other_index } ( @{ $self->_links_data() } );

	return defined( $link ) ? $link->[ -1 ] : undef;
}

=head2 add_scan_entry

Add a scan entry to the specified index with the specified score

This doesn't check whether a link has already been added between the specified items
so don't add the same link multiple times

=cut

sub add_scan_entry {
	state $check = compile( Object, Int, Num );
	my ( $self, $other_index, $score ) = $check->( @ARG );

	push @{ $self->_links_data() }, [ $other_index, $score ];

	# use Data::Dumper;
	# warn Dumper( $self );
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

	my @other_scores;
	$other_scores[ $size ] = undef;
	pop @other_scores;
	foreach my $link ( @{ $self->_links_data() } ) {
		my ( $other_index, $other_score ) = @$link;
		@other_scores[ $other_index ] = $other_score;
	}
	return \@other_scores;
}

=head2 get_idx_and_score_of_lowest_score_of_id

Get the index and score of the link with lowest score
that's active and not excluded according to the specified data

The actives are specified as an array that contains a defined value
in each position that's active and an undef in all others

The excluded_indices is sorted array of the indices that are excluded

Prerequisites:

 * $excluded_indices must be sorted in numerical ascending order

=cut

sub get_idx_and_score_of_lowest_score_of_id {
	state $check = compile( Object, ArrayRef, ArrayRef[Int] );
	my ( $self, $actives, $excluded_indices ) = $check->( @ARG );

	my $links_data = $self->_links_data();

	# It would be better if this were full deterministic (ie deterministically chose
	# the same index amongst several with the same best score)
	my $best_link_index = min_by {
		$links_data->[ $ARG ]->[ -1 ];
	}
	grep {
		my $other_idx         = $links_data->[ $ARG ]->[ 0 ];
		# if ( $other_idx =~ /item/ ) {
		# 	use Data::Dumper;
		# 	use Carp qw/ confess /;
		# 	confess Dumper( $self ) . ' ';
		# }
		my $index_is_active   = defined( $actives->[ $other_idx ] );
		my $index_is_excluded = bsearch { $ARG <=> $other_idx } @$excluded_indices;

		( $index_is_active && ! $index_is_excluded );
	} ( 0 .. $#$links_data );

	return defined( $best_link_index )
		? $links_data->[ $best_link_index ]
		: [ undef, 'inf' ];
}

=head2 add_merged_pair

Make a LinkList of the specified array of arrays of index and score

=cut

sub make_link_list {
	state $check = compile( ClassName, ArrayRef[Tuple[Int,Num]] );
	my ( $class, $data ) = $check->( @ARG );

	return $class->new( _links_data => $data );
}

1;
