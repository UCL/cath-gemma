package Cath::Gemma::Executor;

=head1 NAME

Cath::Gemma::Executor - Execute a Cath::Gemma::Compute::WorkBatchList of batches in some way

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars  /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile         /;
use Types::Standard   qw/ ArrayRef Object /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatchList
	CathGemmaExecSync
/;

=head2 requires execute

TODOCUMENT

=cut

requires 'execute';

=head2 before execute

TODOCUMENT

=cut

before execute => sub {
	state $check = compile( Object, CathGemmaComputeWorkBatchList, CathGemmaExecSync );

	$check->( @ARG );

	# use Carp qw/ cluck /;
	# cluck "\n\n\n****** In Executor::execute, num_batches is : " . $ARG[ 1 ]->num_batches();
};

1;