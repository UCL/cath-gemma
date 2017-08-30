package Cath::Gemma::Executor::HpcRunner;

=head1 NAME

Cath::Gemma::Executor::HpcRunner - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars                /;
use v5.10;

# Moo
use Moo::Role;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile                       /;
use Types::Path::Tiny qw/ Path                          /;
use Types::Standard   qw/ ArrayRef Int Maybe Object Str /;

requires 'run_job_array';

=head2 before execute

=cut

before run_job_array => sub {
	state $check = compile( Object, Path, Str, Path, Path, Int, ArrayRef[Maybe[Int]], ArrayRef[Str] );
	$check->( @ARG );
};

1;