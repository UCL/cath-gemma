package Cath::Gemma::Executor;

=head1 NAME

Cath::Gemma::Executor - TODOCUMENT

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

# Cath
use Cath::Gemma::Types qw/
	CathGemmaComputeWorkBatchList
/;

=head2 requires execute

TODOCUMENT

=cut

requires 'execute';

=head2 before execute

TODOCUMENT

=cut

before execute => sub {
	state $check = compile( Object, CathGemmaComputeWorkBatchList );
	$check->( @ARG );
};

1;