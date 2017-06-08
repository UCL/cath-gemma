package Cath::Gemma::Scan::ScansData;

use strict;
use warnings;

# Core
use Carp               qw/ confess                                                              /;
use English            qw/ -no_match_vars                                                       /;
use List::Util         qw/ max maxstr min minstr                                                /;
use POSIX              qw/ ceil log10                                                           /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils    qw/ first_value                                                          /;
use Type::Params       qw/ compile                                                              /;
use Types::Standard    qw/ ArrayRef Bool ClassName HashRef Num Tuple Object Optional slurpy Str /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaScanScanData                                                /;
use Cath::Gemma::Util;

=head2 starting_clusters_of_ids

=cut

has starting_clusters_of_ids => (
	is          => 'rwp',
	isa         => HashRef[Str,ArrayRef[Str]],
	handles_via => 'Hash',
	handles     => {
		count    => 'count',
		is_empty => 'is_empty',
		ids      => 'keys',
	},
	default     => sub { {}; },
);

=head2 scans

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

=head2 sorted_ids

=cut

sub sorted_ids {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [ sort { cluster_name_spaceship( $a, $b ) } ( keys( %{ $self->starting_clusters_of_ids() } ) ) ];
}

=head2 add_starting_clusters

=cut

sub add_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	foreach my $id ( @$ids ) {
		$self->starting_clusters_of_ids()->{ $id } = [ $id ];
	}
}

=head2 add_scan_entry

=cut

sub add_scan_entry {
	state $check = compile( Object, Str, Str, Num );
	my ( $self, $id1, $id2, $score ) = $check->( @ARG );

	foreach my $id ( $id1, $id2 ) {
		if ( ! defined( $self->starting_clusters_of_ids()->{ $id } ) ) {
			use Data::Dumper;
			confess "Cannot add scan_entry for unrecognised ID \"$id\" " . Dumper( $self->starting_clusters_of_ids() );
		}
	}

	my $scans = $self->scans();
	$scans->{ $id1 }->{ $id2 } = $score;
	$scans->{ $id2 }->{ $id1 } = $score;
}


=head2 add_scan_data

=cut

sub add_scan_data {
	state $check = compile( Object, CathGemmaScanScanData );
	my ( $self, $scan_data ) = $check->( @ARG );

	foreach my $scan_entry ( @{ $scan_data->scan_data() } ) {
		$self->add_scan_entry( @$scan_entry );
	}
}


=head2 get_id_and_score_of_lowest_score_of_id

=cut

sub get_id_and_score_of_lowest_score_of_id {
	state $check = compile( Object, Str, Optional[HashRef] );
	my ( $self, $id, $excluded_ids ) = $check->( @ARG );

	if ( $self->count() < 2 ) {
		confess 'Argh TODOCUMENT';
	}

	my $scan_of_id       = $self->scans()->{ $id };
	my @non_excluded_ids = grep { ! defined( $excluded_ids ) || ! defined( $excluded_ids->{ $ARG } ) } keys( %$scan_of_id );
	my $min_score        = min( map { $scan_of_id->{ $ARG } } @non_excluded_ids );

	if ( ! defined( $min_score ) ) {
		my @all_ids      = sort( $self->ids() );
		my $different_id = ( $id eq $all_ids[ 0 ] ) ? $all_ids[ 1 ]
		                                            : $all_ids[ 0 ];
		return [
			$different_id,
			undef
		];
	}

	my $other_id = first_value { $scan_of_id->{ $ARG } == $min_score } sort( keys( %$scan_of_id ) );
	return [
		$other_id,
		$min_score
	];
}

=head2 ids_and_score_of_lowest_score

=cut

sub ids_and_score_of_lowest_score {
	state $check = compile( Object, Optional[Tuple[Num,HashRef]] );
	my ( $self, $extras ) = $check->( @ARG );

	my ( $window_cutoff, $excluded_ids ) = @{ $extras // [] };

	if ( $self->count() < 2 ) {
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
					@{ ordered_cluster_name_pair( $id, $other_id ) },
					$score
				);
			}
		}
	}

	if ( scalar( @result ) == 0 ) {
		return;
	}
	return \@result;
}

=head2 ids_and_score_of_lowest_score_window

=cut

sub ids_and_score_of_lowest_score_window {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my ( $id1, $id2, $score ) = @{ $self->ids_and_score_of_lowest_score() };

	my $evalue_cutoff = ( 10 ** ( ceil( log10( $score ) / 10 ) * 10 ) );

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

=cut

sub remove {
	state $check = compile( Object, Str );
	my ( $self, $id ) = $check->( @ARG );

	my $scans = $self->scans();
	my $starting_clusters = $self->starting_clusters_of_ids()->{ $id };

	if ( ! defined( $starting_clusters ) ) {
		confess "Unable to remove unrecognised cluster ID \"$id\"";
	}

	foreach my $other_id ( sort( keys( %{ $scans->{ $id } } ) ) ) {
		delete $scans->{ $other_id }->{ $id };
	}
	delete $scans->{ $id };

	delete $self->starting_clusters_of_ids()->{ $id };
	return $starting_clusters;
}

=head2 add_node_of_starting_clusters

=cut

sub add_node_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	my $merged_id = id_of_starting_clusters( $ids );
	$self->starting_clusters_of_ids()->{ $merged_id } = $ids;
	return $merged_id;
}

=head2 merge_remove

=cut

sub merge_remove {
	state $check = compile( Object, Str, Str, Optional[Bool] );
	my ( $self, $id1, $id2, $use_depth_first ) = $check->( @ARG );

	my $starting_clusters_1 = $self->remove( $id1 );
	my $starting_clusters_2 = $self->remove( $id2 );

	my @starting_clusters =
		$use_depth_first
		? (                                             @$starting_clusters_1, @$starting_clusters_2   )
		: ( sort { cluster_name_spaceship( $a, $b ) } ( @$starting_clusters_1, @$starting_clusters_2 ) );

	return \@starting_clusters;
}

=head2 merge_add_with_score_of_lowest

=cut

sub merge_add_with_score_of_lowest {
	state $check = compile( Object, Str, Str, Optional[Bool] );
	my ( $self, $id1, $id2, $use_depth_first ) = $check->( @ARG );

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

	my @starting_clusters =
		$use_depth_first
		? (                                             @$starting_clusters_1, @$starting_clusters_2   )
		: ( sort { cluster_name_spaceship( $a, $b ) } ( @$starting_clusters_1, @$starting_clusters_2 ) );

	my $merged_id = id_of_starting_clusters( \@starting_clusters );
	$self->starting_clusters_of_ids()->{ $merged_id } = \@starting_clusters;

	foreach my $new_result ( @new_results ) {
		$self->add_scan_entry( $merged_id, @$new_result );
	}

	return $merged_id;
}

=head2 merge_add_with_score_of_highest

=cut

sub merge_add_with_score_of_highest {
	state $check = compile( Object, Str, Str, Optional[Bool] );
	my ( $self, $id1, $id2, $use_depth_first ) = $check->( @ARG );

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

	my @starting_clusters =
		$use_depth_first
		? (                                             @$starting_clusters_1, @$starting_clusters_2   )
		: ( sort { cluster_name_spaceship( $a, $b ) } ( @$starting_clusters_1, @$starting_clusters_2 ) );

	my $merged_id = id_of_starting_clusters( \@starting_clusters );
	$self->starting_clusters_of_ids()->{ $merged_id } = \@starting_clusters;

	foreach my $new_result ( @new_results ) {
		$self->add_scan_entry( $merged_id, @$new_result );
	}

	return $merged_id;
}

=head2 new_from_starting_clusters

=cut

sub new_from_starting_clusters {
	state $check = compile( ClassName, ArrayRef[Str] );
	my ( $class, $ids ) = $check->( @ARG );

	my $new = $class->new();
	$new->add_starting_clusters( $ids );
	return $new;
}

1;
