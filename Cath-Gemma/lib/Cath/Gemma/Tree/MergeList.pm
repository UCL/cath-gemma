package Cath::Gemma::Tree::MergeList;

=head1 NAME

Cath::Gemma::Tree::MergeList - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                                                      /;
use English             qw/ -no_match_vars                                               /;
use List::Util          qw/ max min sum                                                  /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use List::MoreUtils     qw/ first_index                                                  /;
use Log::Log4perl::Tiny qw/ :easy                                                        /;
use Path::Tiny;
use Type::Params        qw/ compile Invocant                                             /;
use Types::Path::Tiny   qw/ Path                                                         /;
use Types::Standard     qw/ ArrayRef ClassName CodeRef Int Num Object Optional Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Tree::Merge;
use Cath::Gemma::Types  qw/
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
	CathGemmaDiskProfileDirSet
	CathGemmaNodeOrdering
	CathGemmaTreeMerge
/;
use Cath::Gemma::Util;

=head2 merges

TODOCUMENT

=cut

has merges => (
	is          => 'rw',
	isa         => ArrayRef[CathGemmaTreeMerge],
	handles_via => 'Array',
	handles     => {
		all             => 'all',
		count           => 'count',
		is_empty        => 'is_empty',
		merge_of_index  => 'get',
		push            => 'push',
	},
	default => sub { []; },
);

=head2 _get_index_based_tree

TODOCUMENT

Extracts a data structure of the form:

 [
 	'working_19',
 	'working_93',
 	'working_184',
 	'working_185',
 	'working_244',
 	'working_520',
 	'working_1049',
 	'working_1121',
 	'working_1248',
 	'working_1318',
 	[  2,   4 ],
 	[  3,  10 ],
 	[  5,  11 ],
 	[  1,  12 ],
 	[  0,  13 ],
 	[  7,   8 ],
 	[  9,  15 ],
 	[  6,  16 ],
 	[ 14,  17 ],
 ];

....from $self->merges(), which is of the form:

 [
 	bless( { 'mergee_a' => 'working_184',        'mergee_b' => 'working_244',         'score' => '1.18e-31' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_185',        'mergee_b' => $VAR1->{'merges'}[0],  'score' => '6.68e-24' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_520',        'mergee_b' => $VAR1->{'merges'}[1],  'score' => '1.15e-23' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_93',         'mergee_b' => $VAR1->{'merges'}[2],  'score' => '1.88e-21' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_19',         'mergee_b' => $VAR1->{'merges'}[3],  'score' => '2.50e-22' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_1121',       'mergee_b' => 'working_1248',        'score' => '7.42e-20' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_1318',       'mergee_b' => $VAR1->{'merges'}[5],  'score' => '6.87e-18' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => 'working_1049',       'mergee_b' => $VAR1->{'merges'}[6],  'score' => '1.22e-11' }, 'Cath::Gemma::Tree::Merge' ),
 	bless( { 'mergee_a' => $VAR1->{'merges'}[4], 'mergee_b' => $VAR1->{'merges'}[7],  'score' => '9.76e-05' }, 'Cath::Gemma::Tree::Merge' )
 ]

Try to avoid doing this sort of work elsewhere - it's a bit messy and is best encapsulated here.

=cut

sub _get_index_based_tree {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	# Grab the starting nodes
	my $nodes                     = $self->starting_clusters();
	my %index_of_starting_cluster = map { ( $nodes->[ $ARG ], $ARG ); } ( 0 .. $#$nodes );

	# Prepare a data structure to store the merge nodes' indices (in the new data structure)
	# under the key of a reference to the merge object. This data structure is a bit ugly
	# but is encapsulated within this short function.
	my %index_of_node_ref;

	# Loop over the merges
	my $merges = $self->merges();
	foreach my $merge ( @{ $self->merges() } ) {
		my $mergee_a = $merge->mergee_a();
		my $mergee_b = $merge->mergee_b();
		my $score    = $merge->score();

		my $get_mergee_index = sub {
			my $mergee = shift;
			my $is_a_merge = ( eval { $mergee->isa( 'Cath::Gemma::Tree::Merge' ) } );
			return $is_a_merge ? $index_of_node_ref        { $mergee }
			                   : $index_of_starting_cluster{ $mergee }
		};
		my $mergee_index_a = $get_mergee_index->( $mergee_a );
		my $mergee_index_b = $get_mergee_index->( $mergee_b );

		push @$nodes, [ $mergee_index_a, $mergee_index_b ];
		$index_of_node_ref{ $merge } = $#$nodes;
	}

	#
	return $nodes;
}

=head2 calc_depths

Calculate the depths of each of the merge nodes, where the depth
is the number of edges between the node in question and the root node.

Returns a reference to an array of (positive integer) depths, one for
each merge node.

=cut

sub calc_depths {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $stuff = $self->_get_index_based_tree();

	my $first_merge_idx = first_index { ref( $ARG ) eq 'ARRAY' } @$stuff;
	my $num_merges = scalar( @$stuff ) - $first_merge_idx;
	my @depths = ( 0 ) x $num_merges;

	foreach my $depth_idx ( reverse( 0 .. $#depths ) ) {
		my $merge = $stuff->[ $depth_idx + $first_merge_idx];
		my $depth = $depths[ $depth_idx  ];
		foreach my $child ( @$merge ) {
			if ( $child >= $first_merge_idx ) {
				$depths[ $child - $first_merge_idx ] = $depth + 1;
			}
		}
	}

	return \@depths;
}


=head2 _calc_heights_impl

Implement the calculations of node heights using a the specified
function to determine how to combine the heights of the child nodes.

Returns a reference to an array of (positive integer) heights, one for
each merge node.

=cut

sub _calc_heights_impl {
	state $check = compile( Object, CodeRef );
	my ( $self, $fn ) = $check->( @ARG );

	my $stuff = $self->_get_index_based_tree();
	my @heights;

	my $first_merge_idx = first_index { ref( $ARG ) eq 'ARRAY' } @$stuff;

	foreach my $merge_idx ( $first_merge_idx .. $#$stuff ) {
		my $merge = $stuff->[ $merge_idx ];
		my ( $a, $b ) = @$merge;
		my $height_of_a = ( $a >= $first_merge_idx ) ? $heights[ $a - $first_merge_idx ] : 0;
		my $height_of_b = ( $b >= $first_merge_idx ) ? $heights[ $b - $first_merge_idx ] : 0;
		push @heights, 1 + $fn->( $height_of_a, $height_of_b );
	}

	return \@heights;
}

=head2 calc_heights

Calculate the heights of each of the merge nodes, where the height
is the maximum number of edges between the node in question and any
of the leaf nodes (ie starting clusters).

Returns a reference to an array of (positive integer) heights, one for
each merge node.

=cut

sub calc_heights {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_calc_heights_impl( sub { max( @ARG ); } );
}

=head2 calc_min_heights

Calculate the min-heights of each of the merge nodes, where the min-height
is the minimum number of edges between the node in question and any
of the leaf nodes (ie starting clusters).

Returns a reference to an array of (positive integer) heights, one for
each merge node.

=cut

sub calc_min_heights {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return $self->_calc_heights_impl( sub { min( @ARG ); } );
}

=head2 _perform_action_on_trace_style_list

TODOCUMENT

TODO: If efficiency not vital, *might* be simpler to
      have this generate the list of prepped elements
      rather than performing a callback on each of them.

=cut

sub _perform_action_on_trace_style_list {
	state $check = compile( Object, CodeRef );
	my ( $self, $action ) = $check->( @ARG );

	my $max_id = max( @{ $self->starting_clusters() } );
	++$max_id;

	my %file_nodename_of_node_id;

	foreach my $merge ( @{ $self->merges() } ) {
		my $mergee_a_id = $file_nodename_of_node_id{ $merge->mergee_a_id() } // $merge->mergee_a();
		my $mergee_b_id = $file_nodename_of_node_id{ $merge->mergee_b_id() } // $merge->mergee_b();
		$action->( $mergee_a_id, $mergee_b_id, $max_id, $merge );
		$file_nodename_of_node_id{ $merge->id() } = $max_id;
		++$max_id;
	}
}

=head2 to_tracefile_string

TODOCUMENT

TODO: Make this work for IDs like working_1, working_234 etc
TODO: Test this works for IDs like working_1, working_234 etc

=cut

sub to_tracefile_string {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $result_str = '';
	$self->_perform_action_on_trace_style_list( sub {
		state $check = compile( Str, Str, Int, CathGemmaTreeMerge );
		my ( $mergee_a_id, $mergee_b_id, $new_id, $merge ) = $check->( @ARG );

		$result_str .= (
			  $mergee_a_id
			. "\t"
			. $mergee_b_id
			. "\t"
			. $new_id
			. "\t"
			. ( ( defined( $merge->score() ) && lc( $merge->score() ) ne 'inf' ) ? $merge->score() : 100000000 )
			. "\n"
		);
	} );
	return $result_str;
}

=head2 write_to_tracefile

TODOCUMENT

TODO: Make this work for IDs like working_1, working_234 etc
TODO: Test this works for IDs like working_1, working_234 etc

=cut

sub write_to_tracefile {
	state $check = compile( Object, Path );
	my ( $self, $output_file ) = $check->( @ARG );

	$output_file->spew( $self->to_tracefile_string() );
}

=head2 to_newick_string

TODOCUMENT

=cut

sub to_newick_string {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my %newick_str_of_node_id;
	my $last_id;
	foreach my $merge ( @{ $self->merges() } ) {
		my $mergee_a_id = $newick_str_of_node_id{ $merge->mergee_a_id() } // ( $merge->mergee_a() . '' );
		my $mergee_b_id = $newick_str_of_node_id{ $merge->mergee_b_id() } // ( $merge->mergee_b() . '' );
		$last_id = $merge->id();
		$newick_str_of_node_id{ $last_id } = "($mergee_a_id,$mergee_b_id)";
	}

	return $newick_str_of_node_id{ $last_id };
}

=head2 write_to_newick_file

TODOCUMENT

=cut

sub write_to_newick_file {
	state $check = compile( Object, Path );
	my ( $self, $output_file ) = $check->( @ARG );

	$output_file->spew( $self->to_newick_string() . "\n" );
}


=head2 build_from_nodenames_and_merges

TODOCUMENT

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
			score    => $merge->score // 'inf',
		);
		$merge_ref_of_mergee_number{ $nodename } = $merges[ -1 ];
	};

	return __PACKAGE__->new(
		merges => \@merges,
	);
}

=head2 read_from_tracefile

TODOCUMENT

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

TODOCUMENT

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
	return [ cluster_name_spaceship_sort( keys ( %starting_clusters ) ) ];
}

=head2 starting_cluster_lists

TODOCUMENT

=cut

sub starting_cluster_lists {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [ map { [ $ARG ] } @{ $self->starting_clusters() } ];
}

=head2 merge_cluster_lists

TODOCUMENT

=cut

sub merge_cluster_lists {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	return [
		map
		{ $ARG->starting_nodes( $clusts_ordering ); }
		$self->all()
	];
}

=head2 inital_scans_of_starting_clusters

TODOCUMENT

=cut

sub inital_scans_of_starting_clusters {
	state $check = compile( Invocant, ArrayRef[Str] );
	my ( $proto, $starting_clusters ) = $check->( @ARG );

	my @results;
	for (my $cluster_ctr = 0; $cluster_ctr < $#$starting_clusters; ++$cluster_ctr) {
		my $starting_cluster = $starting_clusters->[ $cluster_ctr ];
		push @results, [
			$starting_clusters->[ $cluster_ctr ],
			[ @$starting_clusters[ ( $cluster_ctr + 1 ) .. $#$starting_clusters ] ]
		];
	}

	return \@results;
}

=head2 inital_scan_lists_of_starting_clusters

TODOCUMENT

=cut

sub inital_scan_lists_of_starting_clusters {
	state $check = compile( Invocant, ArrayRef[Str] );
	my ( $proto, $starting_clusters ) = $check->( @ARG );

	return [
		map
		{ [ $ARG->[ 0 ], $ARG->[ 1 ] ]; }
		@{ $proto->inital_scans_of_starting_clusters( $starting_clusters ) }
	];
}

=head2 initial_scans

TODOCUMENT

=cut

sub initial_scans {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $starting_clusters = $self->starting_clusters();
	return $self->inital_scans_of_starting_clusters( $self->starting_clusters() );
}

=head2 initial_scan_lists

TODOCUMENT

=cut

sub initial_scan_lists {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return [
		map
		{ [ [ $ARG->[ 0 ] ], $ARG->[ 1 ] ]; }
		@{ $self->initial_scans() }
	];
}

=head2 later_scans

TODOCUMENT

=cut

sub later_scans {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= 'simple_ordering';

	my %clusters = map { ( $ARG, 1 ) } @{ $self->starting_clusters() };
	my $merges = $self->merges();

	my @results;
	foreach my $merge ( @$merges ) {
		my $new_id = $merge->id         ( $clusts_ordering );
		my $id_a   = $merge->mergee_a_id( $clusts_ordering );
		my $id_b   = $merge->mergee_b_id( $clusts_ordering );

		delete $clusters{ $id_a };
		delete $clusters{ $id_b };

		if ( scalar( keys ( %clusters ) ) > 0 ) {
			push @results, [ $new_id, [ cluster_name_spaceship_sort( keys ( %clusters ) ) ] ];
		}

		$clusters{ $new_id } = 1;
	}

	return \@results;
}

=head2 later_scan_lists

TODOCUMENT

=cut

sub later_scan_lists {
	state $check = compile( Object, Optional[CathGemmaNodeOrdering] );
	my ( $self, $clusts_ordering ) = $check->( @ARG );

	return [
		map
		{ [ [ $ARG->[ 0 ] ], $ARG->[ 1 ] ]; }
		@{ $self->later_scans( $clusts_ordering ) }
	]
}

=head2 ensure_all_alignments

TODOCUMENT

=cut

sub ensure_all_alignments {
	state $check = compile( Object, CathGemmaNodeOrdering, CathGemmaDiskExecutables, CathGemmaDiskProfileDirSet );
	my ( $self, $clusts_ordering, $exes, $profile_dir_set ) = $check->( @ARG );

	foreach my $starting_cluster ( @{ $self->starting_clusters() } ) {
		Cath::Gemma::Tool::Aligner->make_alignment_file( $exes, [ $starting_cluster ], $profile_dir_set );
	}

	foreach my $merge ( @{ $self->merges() } ) {
		Cath::Gemma::Tool::Aligner->make_alignment_file( $exes, $merge->starting_nodes( $clusts_ordering ), $profile_dir_set );
	}
}

=head2 archive_in_dir

TODOCUMENT

=cut

sub archive_in_dir {
	state $check = compile( Object, Str, CathGemmaNodeOrdering, Path, Path );
	my ( $self, $basename, $clusts_ordering, $aln_dir, $output_dir ) = $check->( @ARG );

	DEBUG "Archiving $basename [$clusts_ordering] to $output_dir (with alignments from $aln_dir)";

	if ( ! -d $output_dir ) {
		$output_dir->mkpath()
			or confess "Unable to make results archive directory \"$output_dir\" : $OS_ERROR";
	}

	$self->write_to_newick_file( $output_dir->child( $basename . '.newick' ) );
	$self->write_to_tracefile  ( $output_dir->child( $basename . '.trace'  ) );

	my @src_dest_aln_file_pairs = map {
		my $starting_cluster  = $ARG;
		[
			$aln_dir->child( alignment_filebasename_of_starting_clusters( [ $starting_cluster ] ) ),
			$output_dir->child( $starting_cluster . alignment_profile_suffix() )
		];
	} @{ $self->starting_clusters() };


	$self->_perform_action_on_trace_style_list( sub {
		state $check = compile( Str, Str, Int, CathGemmaTreeMerge );
		my ( $mergee_a_id, $mergee_b_id, $new_id, $merge ) = $check->( @ARG );

		push @src_dest_aln_file_pairs, [
			$aln_dir->child( alignment_filebasename_of_starting_clusters( $merge->starting_nodes( $clusts_ordering ) ) ),
			$output_dir->child( $new_id . alignment_profile_suffix() )
		];
	} );

	foreach my $src_dest_aln_file_pair ( @src_dest_aln_file_pairs ) {
		my ( $source_aln_file, $dest_aln_file ) = @$src_dest_aln_file_pair;
		if ( ! -s $source_aln_file ) {
			confess "Argh";
		}

		$source_aln_file->copy( $dest_aln_file )
			or confess "Unable to copy alignment file \"$source_aln_file\" to \"$dest_aln_file\" whilst archiving MergeList : $OS_ERROR";
	}
}

=head2 geometric_mean_score

TODOCUMENT

=cut

sub geometric_mean_score {
	state $check = compile( Object, Optional[Num] );
	my ( $self, $lower_bound ) = $check->( @ARG );

	my @ln_scores = ( map { log( $ARG->score_with_lower_bound( $lower_bound // 1e-300 ) ) } @{ $self->merges() } );

	return exp( sum( @ln_scores ) / scalar( @ln_scores ) );
}

# =head2 rescore

# TODOCUMENT

# =cut

# sub rescore {
# 	state $check = compile( Object, CathGemmaDiskGemmaDirSet, CathGemmaNodeOrdering );
# 	my ( $self, $gemma_dir_set, $clusts_ordering ) = $check->( @ARG );

# 	foreach my $merge ( @{ $self->merges() } ) {
# 		$merge->score(
# 			get_pair_scan_score(
# 				$merge->starting_clusters_a( $clusts_ordering ),
# 				$merge->starting_clusters_b( $clusts_ordering ),
# 			)
# 		);
# 	}
# 	# state $check = compile( Object );
# 	# my ( $self ) = $check->( @ARG );
# }

=head2 rescore_copy

TODOCUMENT

=cut

sub rescore_copy {
	state $check = compile( Object, CathGemmaDiskGemmaDirSet, CathGemmaNodeOrdering );
	my ( $self, $gemma_dir_set, $clusts_ordering ) = $check->( @ARG );

	my $copy = bless( dclone( $self ), __PACKAGE__ );
	$copy->rescore( $gemma_dir_set, $clusts_ordering);
	return $copy;
}

1;
