package Cath::Gemma::Tree::MergeBundler;

=head1 NAME

Cath::Gemma::Tree::MergeBundler - Define a Moo::Role for choosing the next list of merges to investigate/perform for a specified ScansData object

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess         /;
use English             qw/ -no_match_vars  /;
use v5.10;

# Moo
use Moo::Role;
use strictures 2;

# Non-core (local)
use Type::Params        qw/ compile         /;
use Types::Standard     qw/ Object Optional /;

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatchList; # ********** ?? TEMPORARY ?? ************
use Cath::Gemma::Types  qw/
	CathGemmaProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaScanScansData
/;

=head2 requires get_execution_bundle

Require that a consumer of the TreeBuilder role must provide a get_execution_bundle() method that gets the bundle of merges to execute next for given ScansData

=cut

requires 'get_execution_bundle';

=head2 around get_execution_bundle

Check the arguments before passing-through to the consuming class's get_execution_bundle()

Check that the returned execution bundle isn't empty

=cut

around get_execution_bundle => sub {
	my $orig__get_execution_bundle = shift;

	state $check = compile( Object, CathGemmaScanScansData );
	$check->( @ARG );

	# my ( $self, $scans_data ) = $check->( @ARG );
	# if ( $index >= $self->num_steps() ) {
	# 	confess
	# 		  'Unable to estimate_time_to_execute_step_of_index() because the index '
	# 		  . $index . ' is out of range in a task of '
	# 		  . $self->num_steps() . ' steps';
	# }

	my $result = $orig__get_execution_bundle->( @ARG );
	if ( scalar( @$result ) == 0 ) {
		confess <<'EOF' ;
The bundle of merges returned by the merge bundler is empty.
This means it has failed to find work to be done and further progress will be impossible.

You will need to investigate this problem and fix it.

Of possible relevance: we have previously seen this occur when the evalue window was being
chosen such that it inadvertently excluded the value that it was chosen to include.
This was due to the nuances of floating-point numbers.
evalue_window_ceiling() and evalue_window_floor() were tweaked to address this problem
(after tests were added to demonstrate it).
EOF
	}
	return $result;
};

=head2 get_query_scs_and_match_scs_list_of_bundle

TODOCUMENT

=cut

sub get_query_scs_and_match_scs_list_of_bundle {
	state $check = compile( Object, CathGemmaScanScansData );
	my ( $self, $scans_data ) = $check->( @ARG );

	my $bundle_mergee_id_pairs = [
		map {
			[ @$ARG[ 0, 1 ] ];
		} @{ $self->get_execution_bundle( $scans_data ) }
	];
	my $merge_details = $scans_data->no_op_merge_pairs( $bundle_mergee_id_pairs );
	return [
		grep {
			scalar( @{ $ARG->[ 0 ] } ) > 0
			&&
			scalar( @{ $ARG->[ 1 ] } ) > 0
		}
		map {
			[ @$ARG[ 1, 2 ] ];
		} @$merge_details
	];
}

=head2 requires get_ordered_merges

TODOCUMENT

=cut

requires 'get_ordered_merges';

=head2 get_ordered_merges

TODOCUMENT

=cut

before get_ordered_merges => sub {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
};

=head2 make_work_batch_list_of_query_scs_and_match_scs_list

TODOCUMENT

=cut

sub make_work_batch_list_of_query_scs_and_match_scs_list {
	state $check = compile( Object, CathGemmaScanScansData, CathGemmaDiskGemmaDirSet, Optional[CathGemmaProfileType] );
	my ( $self, $scans_data, $gemma_dir_set, @profile_type ) = $check->( @ARG );

	return Cath::Gemma::Compute::WorkBatchList->make_work_batch_list_of_query_scs_and_match_scs_list(
		$self->get_query_scs_and_match_scs_list_of_bundle( $scans_data ),
		$gemma_dir_set,
		@profile_type,
	);
}

1;
