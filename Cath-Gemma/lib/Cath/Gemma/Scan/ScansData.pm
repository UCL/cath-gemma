package Cath::Gemma::Scan::ScansData;

use strict;
use warnings;

# Core
use Carp               qw/ confess                                                        /;
use English            qw/ -no_match_vars                                                 /;
use List::Util         qw/ max maxstr min minstr                                          /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils    qw/ first_value                                                    /;
use Type::Params       qw/ compile                                                        /;
use Types::Standard    qw/ ArrayRef Bool ClassName HashRef Num Object Optional slurpy Str /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaScanScanData                                          /;
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
	},
	default     => sub { {}; },
);

=head2 scans

=cut

has scans => (
	is          => 'rwp',
	isa         => HashRef[HashRef[Num]],
	default     => sub { {}; },
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


=head2 ids_and_score_of_lowest_score

=cut

sub ids_and_score_of_lowest_score {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $really_bad_score = 100000000;

	my $scans = $self->scans();
	my @all_ids = sort( keys( %{ $self->starting_clusters_of_ids() } ) );
	if ( scalar( @all_ids ) <= 1 ) {
		confess "Argh TODOCUMENT";
	}
	my @result;
	foreach my $id ( sort( keys( %{ $scans } ) ) ) {
		my $scan_of_id = $scans->{ $id };
		my $min_score = min( values( %$scan_of_id ) );

		if ( ! defined( $min_score ) ) {
			if ( scalar( @result ) == 0 ) {
				@result = (
					$id,
					( ( $all_ids[ 0 ] eq $id ) ? $all_ids[ 1 ] : $all_ids[ 0 ] ),
					$really_bad_score
				);
			}
			$min_score = $really_bad_score;
			next;
		}

		if ( scalar( @result ) == 0 || $min_score < $result[ -1 ] ) {
			my $other_id = first_value { $scan_of_id->{ $ARG } == $min_score } sort( keys( %$scan_of_id ) );
			my $spaceship_result = cluster_name_spaceship( $id, $other_id );
			@result = (
				( $spaceship_result < 0 ) ? $id       : $other_id,
				( $spaceship_result < 0 ) ? $other_id : $id,
				$min_score
			);
		}
	}

	return ( scalar( @result ) > 0 )
		? \@result
		: [ $all_ids[ 0 ], $all_ids[ 1 ], $really_bad_score ];
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
