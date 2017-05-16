package Cath::Gemma::Util;

=head1 NAME

Cath::Gemma::Util - TODOCUMENT

=cut

use strict;
use warnings;

use Carp qw/ confess /;
use Digest::MD5 qw/ md5_hex /;
use Exporter qw/ import /;

our @EXPORT = qw/
	alignment_filename_of_starting_clusters
	cluster_name_spaceship
	id_of_starting_clusters
	mergee_is_starting_cluster
	raw_sequences_filename_of_starting_clusters
	/;

=head2 mergee_is_starting_cluster

=cut

sub mergee_is_starting_cluster {
	my $mergee = shift;
	return ! ref( $mergee );
}


=head2 cluster_name_spaceship

=cut

sub cluster_name_spaceship {
	my $a = shift;
	my $b = shift;

	if ( $a =~ /^(\D*)([\d]+)(\D*)$/ ) {
		my $prefix   = $1;
		my $number_a = $2;
		my $suffix   = $3;
		
		if ( $b =~ /^$prefix([\d]+)$suffix$/ ) {
			my $number_b = $1;
			return ( $number_a <=> $number_b );
		}
	}
	return ( $a cmp $b );
}

=head2 id_of_starting_clusters

=cut

sub id_of_starting_clusters {
	my $starting_clusters = shift;
	if ( scalar( @$starting_clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of starting clusters";
	}
	if ( scalar( @$starting_clusters ) == 1 ) {
		return $starting_clusters->[ 0 ]
	}
	return md5_hex( @$starting_clusters );
}

=head2 alignment_filename_of_starting_clusters

=cut

sub alignment_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . '.faa';
}

=head2 raw_sequences_filename_of_starting_clusters

=cut

sub raw_sequences_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . '.fa';
}

1;
