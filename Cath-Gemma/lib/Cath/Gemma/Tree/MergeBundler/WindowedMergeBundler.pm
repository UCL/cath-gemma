package Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler;

=head1 NAME

Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler - Create a bundle containing the merges within the current-best window of evalues

=cut

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars          /;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

with ( 'Cath::Gemma::Tree::MergeBundler' );

=head2 get_execution_bundle

TODOCUMENT

=cut

sub get_execution_bundle {
	my ( $self, $scans_data ) = @ARG;
	return $scans_data->ids_and_score_of_lowest_score_window();
}

=head2 get_ordered_merges

TODOCUMENT

=cut

sub get_ordered_merges {

}

1;
