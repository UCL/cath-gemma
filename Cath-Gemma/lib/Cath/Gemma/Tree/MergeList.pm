package Cath::Gemma::Tree::MergeList;

use strict;
use warnings;

# Core
use Carp               qw/ confess                                           /;
use English            qw/ -no_match_vars                                    /;
use List::Util         qw/ max sum                                           /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile Invocant                                  /;
use Types::Path::Tiny  qw/ Path                                              /;
use Types::Standard    qw/ ArrayRef Bool ClassName Object Optional Str Tuple /;

# Cath
use Cath::Gemma::Tree::Merge;
use Cath::Gemma::Types qw/ CathGemmaTreeMerge                                /;
use Cath::Gemma::Util;

=head2 merges

=cut
has merges => (
	is          => 'rw',
	isa         => ArrayRef[CathGemmaTreeMerge],
	handles_via => 'Array',
	handles     => {
		count          => 'count',
		is_empty       => 'is_empty',
		merge_of_index => 'get',
		push           => 'push',
	},
	default => sub { []; },
);


=head2 to_tracefile_string

TODO: Make this work for IDs like working_1, working_234 etc
TODO: Test this works for IDs like working_1, working_234 etc

=cut

sub to_tracefile_string {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $max_id = max( @{ $self->starting_clusters() } );
	++$max_id;

	my %file_nodename_of_node_id;

	my $result_str = '';
	foreach my $merge ( @{ $self->merges() } ) {
		my $mergee_a_id = $file_nodename_of_node_id{ $merge->mergee_a_id() } // $merge->mergee_a();
		my $mergee_b_id = $file_nodename_of_node_id{ $merge->mergee_b_id() } // $merge->mergee_b();
		$result_str .= (
			  $mergee_a_id
			. "\t"
			. $mergee_b_id
			. "\t"
			. $max_id
			. "\t"
			. $merge->score()
			. "\n"
		);
		$file_nodename_of_node_id{ $merge->id() } = $max_id;
		++$max_id;
	}

	return $result_str;
}

=head2 write_to_tracefile

TODO: Make this work for IDs like working_1, working_234 etc
TODO: Test this works for IDs like working_1, working_234 etc

=cut

sub write_to_tracefile {
	state $check = compile( Object, Path );
	my ( $self, $output_file ) = $check->( @ARG );

	$output_file->spew( $self->to_tracefile_string() );
}

=head2 build_from_nodenames_and_merges

=cut

sub build_from_nodenames_and_merges {
	state $check = compile( ClassName, ArrayRef[ Tuple[ Str,CathGemmaTreeMerge ] ] );
	my ( $class, $nodenames_and_merges ) = $check->( @ARG );

	my %merge_ref_of_mergee_number;
	my @merges;
	foreach my $nodename_and_merge ( @$nodenames_and_merges ) {
		my ( $nodename, $merge ) = @$nodename_and_merge;

		my $fix_mergee = sub {
			my $mergee = shift;
			return $merge_ref_of_mergee_number{ $mergee } // $mergee;
		};

		push @merges, Cath::Gemma::Tree::Merge->new(
			mergee_a => $fix_mergee->( $merge->mergee_a() ),
			mergee_b => $fix_mergee->( $merge->mergee_b() ),
			score    => $merge->score,
		);
		$merge_ref_of_mergee_number{ $nodename } = $merges[ -1 ];
	};

	return __PACKAGE__->new(
		merges => \@merges,
	);
}

=head2 read_from_tracefile

=cut

sub read_from_tracefile {
	state $check = compile( ClassName, Path );
	my ( $class, $input_path ) = $check->( @ARG );

	my $data = $input_path->slurp();

	my @merges;
	my @lines = split( /\n/, $data );
	foreach my $line ( @lines ) {
		my @line_parts = split( /\s+/, $line );
		if ( scalar( @line_parts ) != 4 ) {
			confess "Cannot parse line \"$line\" from tracefile $input_path";
		}
		my ( $mergee_a, $mergee_b, $merged, $score ) = @line_parts;

		push @merges, [
			$merged,
			Cath::Gemma::Tree::Merge->new(
				mergee_a => $mergee_a,
				mergee_b => $mergee_b,
				score    => $score,
			),
		];
	};

	return __PACKAGE__->build_from_nodenames_and_merges( \@merges );
}

=head2 starting_clusters

=cut

sub starting_clusters {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

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

=head2 inital_scans_of_starting_clusters

=cut

sub inital_scans_of_starting_clusters {
	state $check = compile( Invocant, ArrayRef[Str] );
	my ( $proto, $starting_clusters ) = $check->( @ARG );

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

=head2 initial_scans

=cut

sub initial_scans {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $starting_clusters = $self->starting_clusters();
	return $self->inital_scans_of_starting_clusters( $self->starting_clusters() );
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

=head2 geometric_mean_score

=cut

sub geometric_mean_score {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my @ln_scores = ( map { log( $ARG->score() ) } @{ $self->merges() } );

	return exp( sum( @ln_scores ) / scalar( @ln_scores ) );
}

1;