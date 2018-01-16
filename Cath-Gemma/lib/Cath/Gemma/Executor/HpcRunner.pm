package Cath::Gemma::Executor::HpcRunner;

=head1 NAME

Cath::Gemma::Executor::HpcRunner - Actually run an HPC batch script (wrapping script/execute_work_batch.pl) for HpcExecutor in some ways

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

# Cath::Gemma
use Cath::Gemma::Types  qw/
	TimeSeconds
	/;

=head2 requires execute

TODOCUMENT

=cut

requires 'run_job_array';

=head2 before execute

TODOCUMENT

=cut

before run_job_array => sub {
	state $check = compile( Object, Path, Str, Path, Path, Int, ArrayRef[Maybe[Int]], ArrayRef[Str], TimeSeconds );
	$check->( @ARG );
};

=head2 requires wait_for_jobs

TODOCUMENT

=cut

requires 'wait_for_jobs';

=head2 before wait_for_jobs

TODOCUMENT

=cut

before wait_for_jobs => sub {
	state $check = compile( Object, ArrayRef[Maybe[Int]] );
	$check->( @ARG );
};

1;