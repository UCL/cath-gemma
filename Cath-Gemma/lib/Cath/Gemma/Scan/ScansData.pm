package Cath::Gemma::Scan::ScansData;

use strict;
use warnings;

# Core
use Carp                qw/ confess                                                         /;
use English             qw/ -no_match_vars                                                  /;
use List::Util          qw/ max maxstr min minstr sum                                       /;
use POSIX               qw/ log10                                                           /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils     qw/ first_value                                                     /;
use Log::Log4perl::Tiny qw/ :easy                                                           /;
use Type::Params        qw/ compile                                                         /;
use Types::Standard     qw/ ArrayRef ClassName HashRef Num Tuple Object Optional slurpy Str /;

# Cath
use Cath::Gemma::StartingClustersOfId;
use Cath::Gemma::Types qw/
	CathGemmaNodeOrdering
	CathGemmaScanScanData
	CathGemmaScanScansData
	CathGemmaStartingClustersOfId
/;
use Cath::Gemma::Util;

=head2 starting_clusters_of_ids

TODOCUMENT

=cut

has starting_clusters_of_ids => (
	is          => 'rwp',
	isa         => CathGemmaStartingClustersOfId,
	handles     => {
		# ids                               => 'keys',
		# is_empty                          => 'is_empty',
		add_separate_starting_clusters    => 'add_separate_starting_clusters',
		add_starting_clusters_group_by_id => 'add_starting_clusters_group_by_id',
		contains_id                       => 'contains',
		count                             => 'count',
		get_starting_clusters_of_id       => 'get_starting_clusters_of_id',
		no_op_merge_pair                  => 'no_op_merge_pair',
		no_op_merge_pairs                 => 'no_op_merge_pairs',
		remove_id                         => 'remove_id',
		sorted_ids                        => 'sorted_ids',
	},
	default     => sub { Cath::Gemma::StartingClustersOfId->new(); },
);

=head2 scans

TODOCUMENT

=cut

has scans => (
	is          => 'rwp',
	isa         => HashRef[HashRef[Num]],
	default     => sub { {}; },
	handles_via => 'Hash',
	handles     => {
		scan_ids => 'keys',
	},
);

=head2 add_scan_entry

TODOCUMENT

=cut

sub add_scan_entry {
	state $check = compile( Object, Str, Str, Num );
	my ( $self, $id1, $id2, $score ) = $check->( @ARG );

	foreach my $id ( $id1, $id2 ) {
		if ( ! defined( $self->contains_id( $id ) ) ) {
			use Data::Dumper;
			confess "Cannot add scan_entry for unrecognised ID \"$id\" " . Dumper( $self->starting_clusters_of_ids() );
		}
	}

	my $scans = $self->scans();
	$scans->{ $id1 }->{ $id2 } = $score;
	$scans->{ $id2 }->{ $id1 } = $score;
}


=head2 add_scan_data

TODOCUMENT

=cut

sub add_scan_data {
	state $check = compile( Object, CathGemmaScanScanData );
	my ( $self, $scan_data ) = $check->( @ARG );

	foreach my $scan_entry ( @{ $scan_data->scan_data() } ) {
		$self->add_scan_entry( @$scan_entry );
	}
}


=head2 get_id_and_score_of_lowest_score_of_id

TODOCUMENT

=cut

sub get_id_and_score_of_lowest_score_of_id {
	state $check = compile( Object, Str, Optional[HashRef] );
	my ( $self, $id, $excluded_ids ) = $check->( @ARG );

	$excluded_ids //= {};

	if ( $self->count() < 2 ) {
		confess 'Argh TODOCUMENT';
	}

	my $scan_of_id       = $self->scans()->{ $id };
	my @non_excluded_ids = grep { ! defined( $excluded_ids->{ $ARG } ) } keys( %$scan_of_id );
	my $min_score        = min( map { $scan_of_id->{ $ARG } } @non_excluded_ids );

	if ( ! defined( $min_score ) ) {
		my @all_ids      = @{ $self->sorted_ids() };
		my $different_id = ( $id eq $all_ids[ 0 ] ) ? $all_ids[ 1 ]
		                                            : $all_ids[ 0 ];
		return [
			$different_id,
			undef
		];
	}

	my $other_id = first_value {
		( $scan_of_id->{ $ARG } == $min_score ) && ! defined( $excluded_ids->{ $ARG } );
	} sort( keys( %$scan_of_id ) );
	return [
		$other_id,
		$min_score
	];
}

=head2 ids_and_score_of_lowest_score

TODOCUMENT

=cut

sub ids_and_score_of_lowest_score {
	state $check = compile( Object, Optional[Tuple[Num,HashRef]] );
	my ( $self, $extras ) = $check->( @ARG );

	my ( $window_cutoff, $excluded_ids ) = @{ $extras // [] };

	if ( $self->count() < 2 ) {
		DEBUG "Cannot find ids_and_score_of_lowest_score() in this ScansData because count is " . $self->count();
		return [];
	}

	my $scans = $self->scans();
	my @result;
	foreach my $id ( sort( $self->scan_ids() ) ) {
		if ( ! defined( $excluded_ids->{ $id } ) ) {
			my ( $other_id, $score ) = @{ $self->get_id_and_score_of_lowest_score_of_id( $id, $excluded_ids ) };
			if ( defined( $window_cutoff ) && ( ! defined( $score) || $score > $window_cutoff ) ) {
				next;
			}
			if ( scalar( @result ) == 0 || ( defined( $score ) && ( ! defined( $result[ 2 ] ) || $score < $result[ 2 ] ) ) ) {
				@result = (
					cluster_name_spaceship_sort( $id, $other_id ),
					$score
				);
			}
		}
	}

	if ( scalar( @result ) == 0 ) {
		DEBUG "Returning from ids_and_score_of_lowest_score() with no possible result";
		return;
	}
	return \@result;
}

=head2 ids_and_score_of_lowest_score_window

TODOCUMENT

TODO: This could be made more efficient: it doesn't have to find the results
      within the window in order (as at present), it could just find all
      the results in the window and then sort them at the end

=cut

sub ids_and_score_of_lowest_score_window {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my ( $id1, $id2, $score ) = @{ $self->ids_and_score_of_lowest_score() };

	if ( ! defined( $score ) ) {
		confess ' ';
	}

	my $evalue_cutoff = evalue_window_ceiling( $score );

	my @results = ( [ $id1, $id2, $score ] );

	my %excluded_ids = ( $id1 => 1, $id2 => 1 );
	while ( my $next_result_in_window = $self->ids_and_score_of_lowest_score( [ $evalue_cutoff, \%excluded_ids ] ) ) {
		push @results, $next_result_in_window;
		my ( $next_id1, $next_id2, $next_score ) = @$next_result_in_window;
		$excluded_ids{ $next_result_in_window->[ 0 ] } = 1;
		$excluded_ids{ $next_result_in_window->[ 1 ] } = 1;
	}

	return \@results;
}

=head2 remove

TODOCUMENT

=cut

sub remove {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	my $scans = $self->scans();
	foreach my $other_id ( sort( keys( %{ $scans->{ $id } } ) ) ) {
		delete $scans->{ $other_id }->{ $id };
	}
	delete $scans->{ $id };

	return $self->remove_id( $id );
}

=head2 merge_remove

TODOCUMENT

=cut

sub merge_remove {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	splice( @ARG, 0, 3 );

	my $starting_clusters_1 = $self->remove( $id1 );
	my $starting_clusters_2 = $self->remove( $id2 );

	return combine_starting_cluster_names( $starting_clusters_1, $starting_clusters_2, @ARG );
}

=head2 merge_add_with_score_of_lowest

TODOCUMENT

=cut

sub merge_add_with_score_of_lowest {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2 ) = $check->( @ARG );
	splice( @ARG, 0, 3 );

	my $scans = $self->scans();

	my @new_results;
	foreach my $other_id ( sort( keys( %{ $scans->{ $id1 } } ) ) ) {
		if ( $other_id ne $id1 && $other_id ne $id2 ) {
			my $result1 = $scans->{ $id1 }->{ $other_id };
			my $result2 = $scans->{ $id2 }->{ $other_id };
			push @new_results, [
				$other_id,
				defined( $result2 ) ? min( $result2, $result1 ) : $result1
			];
		}
	}

	my $starting_clusters_1 = $self->remove( $id1 );
	my $starting_clusters_2 = $self->remove( $id2 );

	my $starting_clusters = combine_starting_cluster_names( $starting_clusters_1, $starting_clusters_2, @ARG );
	my $merged_id         = id_of_starting_clusters( $starting_clusters );
	$self->starting_clusters_of_ids()->{ $merged_id } = $starting_clusters;

	foreach my $new_result ( @new_results ) {
		$self->add_scan_entry( $merged_id, @$new_result );
	}

	return $merged_id;
}

=head2 merge_add_with_score_of_highest

TODOCUMENT

=cut

sub merge_add_with_score_of_highest {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2 ) = $check->( @ARG );
	splice( @ARG, 0, 3 );

	my $scans = $self->scans();

	my @new_results;
	foreach my $other_id ( sort( keys( %{ $scans->{ $id1 } } ) ) ) {
		if ( $other_id ne $id1 && $other_id ne $id2 ) {
			my $result1 = $scans->{ $id1 }->{ $other_id };
			my $result2 = $scans->{ $id2 }->{ $other_id };
			push @new_results, [
				$other_id,
				defined( $result2 ) ? max( $result2, $result1 ) : $result1
			];
		}
	}

	my $starting_clusters_1 = $self->remove( $id1 );
	my $starting_clusters_2 = $self->remove( $id2 );

	my $starting_clusters = combine_starting_cluster_names( $starting_clusters_1, $starting_clusters_2, @ARG );
	my $merged_id         = id_of_starting_clusters( $starting_clusters );
	$self->starting_clusters_of_ids()->{ $merged_id } = $starting_clusters;

	foreach my $new_result ( @new_results ) {
		$self->add_scan_entry( $merged_id, @$new_result );
	}

	return $merged_id;
}

=head2 merge_add_with_unweighted_geometric_mean_score

TODOCUMENT

=cut

sub merge_add_with_unweighted_geometric_mean_score {
	state $check = compile( Object, Str, Str, CathGemmaScanScansData, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2, $orig_scans ) = $check->( @ARG );

	my $really_bad_score = 100000000;

	my $starting_clusters_1 = $self->get_starting_clusters_of_id( $id1 );
	my $starting_clusters_2 = $self->get_starting_clusters_of_id( $id2 );

	my $scans = $self->scans();

	my @new_results;
	foreach my $other_id ( sort( keys( %{ $scans->{ $id1 } } ) ) ) {
		if ( $other_id ne $id1 && $other_id ne $id2 ) {
			my $other_starting_clusters = $self->get_starting_clusters_of_id( $other_id );
			my @log_10_scores = 0;
			foreach my $starting_cluster ( @$starting_clusters_1, @$starting_clusters_2 ) {
				foreach my $other_starting_cluster ( @$other_starting_clusters ) {
					# if ( $starting_cluster eq '97' && $other_starting_cluster eq '38' ) {
					# 	warn "*******  HERE *******";
					# }
					my $score = $orig_scans->scans()->{ $starting_cluster }->{ $other_starting_cluster };
					# If undefined, make      large
					# If zero,      make very small
					# Otherwise,    use value
					push @log_10_scores, log10( ( $score // 1e10 ) || 1e-200 );
				}
			}
			my $geom_mean_score = 10 ** ( sum( @log_10_scores ) / scalar( @log_10_scores ) );
			push @new_results, [
				$other_id,
				$geom_mean_score
			];
		}
	}

	# Merge the pairs and grab the id of the newly merged node
	my $merged_id = $self->merge_pair( [ [ $id1, $id2 ] ] )->[ 0 ];

	foreach my $new_result ( @new_results ) {
		$self->add_scan_entry( $merged_id, @$new_result );
	}

	# Return the id of the newly merged node
	return $merged_id;
}

=head2 merge_pair

TODOCUMENT

=cut

sub merge_pair {
	state $check = compile( Object, Str, Str, Optional[CathGemmaNodeOrdering] );
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	splice( @ARG, 0, 3 );

	my $merged_starting_clusters = $self->merge_remove( $id1, $id2, @ARG );
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
