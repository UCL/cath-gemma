package Cath::Gemma::MergeList;

use strict;
use warnings;

# Core
use Carp               qw/ confess                                     /;
use English            qw/ -no_match_vars                              /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile                                     /;
use Types::Path::Tiny  qw/ Path                                        /;
use Types::Standard    qw/ ArrayRef Bool ClassName Object Optional Str /;

# Cath
use Cath::Gemma::Merge;
use Cath::Gemma::Types qw/ CathGemmaMerge                              /;
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
	state $check = compile( ClassName, Path );
	my ( $class, $input_path ) = $check->( @ARG );

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

=head2 initial_scans

=cut

sub initial_scans {
	my $self = shift;

	my $starting_clusters = $self->starting_clusters();

	my @results;
	for (my $cluster_ctr = 0; $cluster_ctr < ( scalar( @$starting_clusters ) - 1 ); ++$cluster_ctr) {
		my $starting_cluster = $starting_clusters->[ $cluster_ctr ];
		push @results, [
			$starting_clusters->[ $cluster_ctr ],
			[ @$starting_clusters[ ( $cluster_ctr + 1 ) .. ( scalar ( @$starting_clusters ) - 1 ) ] ]
		];
	}

	return \@results;
}


=head2 later_scans

=cut

sub later_scans {
	state $check = compile( Object, Optional[Bool] );
	my ( $self, $use_depth_first ) = $check->( @ARG );

	$use_depth_first //= 0;

	my %clusters = map { ( $ARG, 1 ) } @{ $self->starting_clusters() };
	my $merges = $self->merges();

	my @results;
	foreach my $merge ( @$merges ) {
		my $new_id = $merge->id         ( $use_depth_first );
		my $id_a   = $merge->mergee_a_id( $use_depth_first );
		my $id_b   = $merge->mergee_b_id( $use_depth_first );

		delete $clusters{ $id_a };
		delete $clusters{ $id_b };

		if ( scalar( keys ( %clusters ) ) > 0 ) {
			push @results, [ $new_id, [ sort { cluster_name_spaceship( $a, $b ) } keys ( %clusters ) ] ];
		}

		$clusters{ $new_id } = 1;
	}

	return \@results;
}


1;