package Cath::Gemma::Tree::MergeBundler;

=head1 NAME

Cath::Gemma::Compute::Task - TODOCUMENT

=cut

use strict;
use warnings;

# Core
# use Carp                qw/ confess        /;
# use List::Util          qw/ sum0           /;
use English             qw/ -no_match_vars  /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
# use Log::Log4perl::Tiny qw/ :easy          /;
# use Types::Standard     qw/ Int Object Maybe /;
use Type::Params        qw/ compile         /;
use Types::Standard     qw/ Object Optional /;

# Cath
# use Cath::Gemma::Disk::TreeDirSet;
use Cath::Gemma::Compute::WorkBatchList; # ********** ?? TEMPORARY ?? ************
use Cath::Gemma::Types  qw/
	CathGemmaCompassProfileType
	CathGemmaDiskGemmaDirSet
	CathGemmaScanScansData
/;
# 	CathGemmaComputeBatchingPolicy
# 	CathGemmaComputeWorkBatch
# 	CathGemmaDiskExecutables
# 	TimeSeconds
# /;
# use Cath::Gemma::Util;



=head2 requires get_execution_bundle

TODOCUMENT

=cut

requires 'get_execution_bundle';

=head2 get_execution_bundle

TODOCUMENT

=cut

before get_execution_bundle => sub {
	state $check = compile( Object, CathGemmaScanScansData );
	$check->( @ARG );
	# my ( $self, $scans_data ) = $check->( @ARG );
	# if ( $index >= $self->num_steps() ) {
	# 	confess
	# 		  'Unable to estimate_time_to_execute_step_of_index() because the index '
	# 		  . $index . ' is out of range in a task of '
	# 		  . $self->num_steps() . ' steps';
	# }
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
	state $check = compile( Object, CathGemmaScanScansData, CathGemmaDiskGemmaDirSet, Optional[CathGemmaCompassProfileType] );
	my ( $self, $scans_data, $gemma_dir_set ) = $check->( @ARG );

	splice( @ARG, 0, 3 );

	return Cath::Gemma::Compute::WorkBatchList->make_work_batch_list_of_query_scs_and_match_scs_list(
		$self->get_query_scs_and_match_scs_list_of_bundle( $scans_data ),
		$gemma_dir_set,
		@ARG
	);
}

1;
