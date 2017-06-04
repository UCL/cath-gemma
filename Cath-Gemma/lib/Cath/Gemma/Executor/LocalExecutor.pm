package Cath::Gemma::Executor::LocalExecutor;

=head1 NAME

Cath::Gemma::Executor::LocalExecutor - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Cath
use Cath::Gemma::Types qw/ CathGemmaDiskExecutables /;

with ( 'Cath::Gemma::Executor' );

=head2 exes

=cut

has exes => (
	is      => 'ro',
	isa     => CathGemmaDiskExecutables,
	default => sub { Cath::Gemma::Disk::Executables->new(); },
);

=head2 execute

Params checked in Cath::Gemma::Executor

=cut

sub execute {
	my ( $self, $build_tasks, $scan_tasks ) = @ARG;


}

1;