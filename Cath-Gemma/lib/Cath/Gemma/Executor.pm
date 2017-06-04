package Cath::Gemma::Executor;

=head1 NAME

Cath::Gemma::Executor - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars           /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile                  /;
use Types::Standard   qw/ ArrayRef Object Optional /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaComputeProfileBuildTask
	CathGemmaComputeProfileScanTask
/;

=head2 requires execute

=cut

requires 'execute';

=head2 before execute

=cut

before execute => sub {
	state $check = compile( Object, Optional[ArrayRef[CathGemmaComputeProfileBuildTask]], Optional[ArrayRef[CathGemmaComputeProfileScanTask]] );
	$check->( @ARG );

	$ARG[ 1 ] //= [];
	$ARG[ 2 ] //= [];

	warn "Checked params " . join( ', ', @ARG );
};

1;