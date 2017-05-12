package Cath::Gemma::MergeList;

use strict;
use warnings;

# Core
use Carp    qw/ confess /;
use English qw/ -no_match_vars /;

# Moo
use Moo;
use MooX::HandlesVia;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Types::Standard qw/ ArrayRef /; 

# Cath
use Cath::Gemma::Merge;
use Cath::Gemma::Types qw/ CathGemmaMerge /; 
use Cath::Gemma::Util;

=head2 merges

=cut
has merges => (
	is          => 'rw',
	isa         => ArrayRef[CathGemmaMerge],
	handles_via => 'Array',
	handles     => {
		count          => 'count',
		is_empty       => 'is_empty',
		merge_of_index => 'get',
	}
);


=head2 read_from_tracefile

=cut

sub read_from_tracefile {
	shift;
	my $input_file = shift;

	my $input_path = path( $input_file );
	my $data       = $input_path->slurp();


	my @merges;
	my @lines = split( /\n/, $data );
	my %merge_ref_of_mergee_number;
	foreach my $line ( @lines ) {
		my @line_parts = split( /\s+/, $line );
		if ( scalar( @line_parts ) != 4 ) {
			confess "Cannot parse line \"$line\" from tracefile $input_path";
		}
		my ( $mergee_a, $mergee_b, $merged, $score ) = @line_parts;

		foreach my $mergee ( \$mergee_a, \$mergee_b ) {
			if ( defined( $merge_ref_of_mergee_number{ $$mergee } ) ) {
				$$mergee = $merge_ref_of_mergee_number{ $$mergee };
			}
		}

		push @merges, Cath::Gemma::Merge->new(
			mergee_a => $mergee_a,
			mergee_b => $mergee_b,
			score    => $score,
		);
		$merge_ref_of_mergee_number{ $merged } = $merges[ -1 ];
	};

	return __PACKAGE__->new(
		merges => \@merges,
	);
}

=head2 starting_clusters

=cut

sub starting_clusters {
	my $self = shift;

	my %starting_clusters;

	foreach my $merge ( @{ $self->merges() } ) {
		foreach my $mergee ( $merge->mergee_a(), $merge->mergee_b() ) {
			if ( mergee_is_starting_cluster( $mergee ) ) {
				$starting_clusters{ $mergee } = 1;
			}
		}
	}
	return [ sort { cluster_name_spaceship( $a, $b ) } ( keys ( %starting_clusters ) ) ];
}

1;