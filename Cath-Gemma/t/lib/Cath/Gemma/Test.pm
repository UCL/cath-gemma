package Cath::Gemma::Test;

=head1 NAME

Cath::Gemma::Test - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess        /;
use English           qw/ -no_match_vars /;
use Exporter          qw/ import         /;
use File::Copy        qw/ copy move      /;
use List::Util        qw/ any            /;
use v5.10;

our @EXPORT = qw/
	bootstrap_is_on
	cath_test_tempdir
	file_matches
	/;

# Test
use Test::Differences;
use Test::More;

# Non-core (local)
use Path::Tiny;
use Type::Params      qw/ compile        /;
use Types::Path::Tiny qw/ Path           /;
use Types::Standard   qw/ Str            /;

# Cath Test
use Cath::Gemma::Test::TestImpl;

=head2 bootstrap_is_on

=cut

sub bootstrap_is_on {
	return Cath::Gemma::Test::TestImpl->singleton()->bootstrap_tests_is_on();
}

=head2 cath_test_tempdir

=cut

sub cath_test_tempdir {
	my %params = @ARG;

	if ( ! any { $ARG eq 'CLEANUP' } map { uc( $ARG ); } keys( %params ) ) {
		$params{ CLEANUP } = ! bootstrap_is_on();
	}

	return Path::Tiny->tempdir( %params );
}

=head2 file_matches

=cut

sub file_matches {
	state $check = compile( Path, Path, Str );
	my ( $got_file, $expected_file, $assertion ) = $check->( @ARG );

	if ( bootstrap_is_on() ) {
		my $bs_summary = "expected test file $expected_file with got file $got_file for test with assertion \"$assertion\"";
		copy( $got_file, $expected_file )
			or confess "Unable to bootstrap $bs_summary : $OS_ERROR";
		diag "Bootstrapped $bs_summary";
	}

	eq_or_diff(
		$got_file->slurp(),
		$expected_file->slurp(),
		$assertion,
	);
}

1;
