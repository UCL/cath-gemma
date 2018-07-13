package Cath::Gemma::Test::TestImpl;

=head1 NAME

Cath::Gemma::Test::TestImpl - TODOCUMENT

=cut

use strict;
use warnings;

# Test
use Test::More;

# Moo
use Moo;
use strictures 2;

with 'Role::Singleton';

# Non-core (local)
use Types::Standard qw/ Bool /;

=head2 bootstrap_tests_is_on

TODOCUMENT

=cut

has bootstrap_tests_is_on => (
	is  => 'lazy',
	isa => Bool,
);

=head2 _build_bootstrap_tests_is_on

TODOCUMENT

=cut

sub _build_bootstrap_tests_is_on {
	my $bootstrap_tests = ( 1 and ( $ENV{ BOOTSTRAP_TESTS } // 0 ) );
	if ( $bootstrap_tests ) {
		diag "NOTE: *** BOOTSTRAP_TESTS is on ***";
	}
	return $bootstrap_tests;
}

1;