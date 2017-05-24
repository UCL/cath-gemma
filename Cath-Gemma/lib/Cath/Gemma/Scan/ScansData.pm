package Cath::Gemma::Scan::ScansData;

use strict;
use warnings;

# Core
use Carp               qw/ confess                                          /;
use English            qw/ -no_match_vars                                   /;
use List::Util         qw/ maxstr min minstr                                /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use strictures 1;

# Non-core (local)
use List::MoreUtils    qw/ first_value                                      /;
use Type::Params       qw/ compile                                          /;
use Types::Standard    qw/ ArrayRef ClassName HashRef Num Object slurpy Str /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaScanScanData                            /;
use Cath::Gemma::Util;

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

=head2 scans_data

=cut

has scans => (
	is          => 'rwp',
	isa         => HashRef[HashRef[Str,Num]],
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
			confess "Cannot add scan_entry for unrecognised ID \"$id\"";
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


=head2 add_scan_data

=cut

sub ids_and_score_of_lowest_score {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $scans = $self->scans();
	my @result;
	foreach my $id ( sort( keys( %$scans ) ) ) {
		my $scan_of_id = $scans->{ $id };
		my $min_score = min( values( %$scan_of_id ) );
		# warn "$id $min_score";
		if ( scalar( @result ) == 0 || $min_score < $result[ -1 ] ) {
			my $other_id = first_value { $scan_of_id->{ $ARG } == $min_score } sort( keys( %$scan_of_id ) );
			@result = ( minstr( $id ), maxstr( $other_id ), $min_score );
			# warn '[' . join( ' ', @result ) . ']'
		}
	}

	return \@result;
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
		# use Data::Dumper;
		# warn Dumper( [$scans->{ $other_id }, $id ] );
		delete $scans->{ $other_id }->{ $id };
	}
	delete $scans->{ $id };

	delete $self->starting_clusters_of_ids()->{ $id };
	return $starting_clusters;
}

=head2 merge

=cut

sub add_node_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $ids ) = $check->( @ARG );

	my $merged_id = id_of_starting_clusters( $ids );
	$self->starting_clusters_of_ids()->{ $merged_id } = $ids;
	return $merged_id;
}

=head2 merge

=cut

sub merge {
	state $check = compile( Object, Str, Str );
	my ( $self, $id1, $id2 ) = $check->( @ARG );

	my $starting_clusters_1 = $self->remove( $id1 );
	my $starting_clusters_2 = $self->remove( $id2 );

	my @starting_clusters = sort { cluster_name_spaceship( $a, $b ) } ( @$starting_clusters_1, @$starting_clusters_2 );

	return \@starting_clusters;
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
