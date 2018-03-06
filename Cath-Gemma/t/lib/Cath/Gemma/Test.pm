package Cath::Gemma::Test;

=head1 NAME

Cath::Gemma::Test - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp              qw/ cluck confess  /;
use English           qw/ -no_match_vars /;
use Exporter          qw/ import         /;
use File::Copy        qw/ copy move      /;
use List::Util        qw/ any            /;
use v5.10;

our @EXPORT = qw/
	bootstrap_is_on
	cath_test_tempdir
	file_matches
	gemma_dir_set_of_superfamily
	make_non_existent_temp_file
	make_non_existent_temp_filename
	profile_dir_set_of_superfamily
	test_data_dir
	test_superfamily_aln_dir
	test_superfamily_data_dir
	test_superfamily_prof_dir
	test_superfamily_scan_dir
	test_superfamily_starting_cluster_dir
	test_superfamily_tree_dir
	tree_dir_set_of_superfamily
	/;

# Test
use Test::Differences;
use Test::More;

# Non-core (local)
use Path::Tiny;
use Type::Params      qw/ compile        /;
use Types::Path::Tiny qw/ Path           /;
use Types::Standard   qw/ Str            /;

# Gemma
use Cath::Gemma::Disk::ProfileDirSet;

# Cath Test
use Cath::Gemma::Test::TestImpl;

=head2 bootstrap_is_on

TODOCUMENT

=cut

sub bootstrap_is_on {
	return Cath::Gemma::Test::TestImpl->singleton()->bootstrap_tests_is_on();
}

=head2 cath_test_tempdir

TODOCUMENT

=cut

sub cath_test_tempdir {
	my %params = @ARG;

	if ( ! any { $ARG eq 'CLEANUP' } map { uc( $ARG ); } keys( %params ) ) {
		$params{ CLEANUP } = ! bootstrap_is_on();
	}

	return Path::Tiny->tempdir( %params );
}

=head2 file_matches

TODOCUMENT

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

	if ( ! -e $got_file ) {
		cluck 'Cannot find got file ' . $got_file;
		ok( -e $got_file );
		sleep 10000;
		return;
	}
	eq_or_diff(
		$got_file->slurp(),
		$expected_file->slurp(),
		$assertion,
	);
}

=head2 gemma_dir_set_of_superfamily

Get the test data GemmaDirSet corresponding to the specified superfamily ID

=cut

sub gemma_dir_set_of_superfamily {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir(
		test_superfamily_data_dir( $superfamily )
	);
}

=head2 make_non_existent_temp_file

Make a temporary file (Path::Tiny) that is *not* created by this function.
This file won't auto-cleanup so the client is responsible for any necessary cleanup.

=cut

sub make_non_existent_temp_file {
	return path( make_non_existent_temp_filename() );
}

=head2 make_non_existent_temp_filename

Make a temporary filename string for a file that is *not* created by this function.
This file won't auto-cleanup so the client is responsible for any necessary cleanup.

=cut

sub make_non_existent_temp_filename {
	my $tempfile = Path::Tiny->tempfile( CLEANUP => 1 );
	return "$tempfile";
}

=head2 profile_dir_set_of_superfamily

Get the test data ProfileDirSet corresponding to the specified superfamily ID

=cut

sub profile_dir_set_of_superfamily {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return Cath::Gemma::Disk::ProfileDirSet->make_profile_dir_set_of_base_dir(
		test_superfamily_data_dir( $superfamily )
	);
}

=head2 test_data_dir

Get the test data directory (t/data)

=cut

sub test_data_dir {
	state $check = compile();
	$check->( @ARG );

	return path( $FindBin::Bin )->parent()->child( 't' )->child( 'data' )->realpath();
}

=head2 test_superfamily_aln_dir

Get the test data alignment sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_aln_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return profile_dir_set_of_superfamily( $superfamily )->aln_dir();
}

=head2 test_superfamily_data_dir

Get the test data sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_data_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return test_data_dir()->child( $superfamily );
}

=head2 test_superfamily_prof_dir

Get the test data profile sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_prof_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return profile_dir_set_of_superfamily( $superfamily )->prof_dir();
}

=head2 test_superfamily_scan_dir

Get the test data scan sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_scan_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return gemma_dir_set_of_superfamily( $superfamily )->scan_dir();
}

=head2 test_superfamily_starting_cluster_dir

Get the test data starting cluster sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_starting_cluster_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return profile_dir_set_of_superfamily( $superfamily )->starting_cluster_dir();
}

=head2 test_superfamily_tree_dir

Get the test data tree sub-directory corresponding to the specified superfamily ID

=cut

sub test_superfamily_tree_dir {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return tree_dir_set_of_superfamily( $superfamily )->tree_dir();
}

=head2 tree_dir_set_of_superfamily

Get the test data TreeDirSet corresponding to the specified superfamily ID

=cut

sub tree_dir_set_of_superfamily {
	state $check = compile( Str );
	my ( $superfamily ) = $check->( @ARG );

	return Cath::Gemma::Disk::TreeDirSet->make_tree_dir_set_of_base_dir(
		test_superfamily_data_dir( $superfamily )
	);
}

1;
