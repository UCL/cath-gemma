package Cath::Gemma::Util;


=head1 NAME

Cath::Gemma::Util - TODOCUMENT

=cut

use strict;
use warnings;

use Exporter qw/ import /;

our @EXPORT = qw/
	cluster_name_spaceship
	mergee_is_starting_cluster
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

1;