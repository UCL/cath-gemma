use strict;
use warnings;

# Core
use Carp              qw/ confess        /;
use English           qw/ -no_match_vars /;
use FindBin;
use v5.10;

use lib $FindBin::Bin . '/../extlib/lib/perl5';
use lib $FindBin::Bin . '/lib';

# Test
use Test::More tests => 3;

# Non-core (local)
use Path::Tiny;
use Type::Params      qw/ compile        /;
use Types::Path::Tiny qw/ Path           /;
use Types::Standard   qw/ Str            /;

# Cath Test
use Cath::Gemma::Test;

# Cath
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Types qw/ CathGemmaCompassProfileType /;

=head2 cmp_compass_profile_type_against_file

TODOCUMENT

=cut

sub cmp_compass_profile_type_against_file {
	state $check = compile( Str, CathGemmaCompassProfileType, Path, Path );
	my ( $assertion_name, $compass_profile_type, $alignment_file, $expected_file ) = $check->( @ARG );

	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.compass_profile_types.XXXXXXXXXXX" );

	my $got_filename = Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
		Cath::Gemma::Disk::Executables->new(),
		$alignment_file,
		$test_out_dir,
		$compass_profile_type,
	)->{ out_filename };

	file_matches(
		$got_filename,
		$expected_file,
		$assertion_name,
	);
}

my $test_base_dir          = path( $FindBin::Bin . '/data' )->realpath();
my $compass_prof_types_dir = $test_base_dir->child( 'compass_profile_types' );
my $alignment_file         = $compass_prof_types_dir->child( '1.10.150.120__1767.faa' );

cmp_compass_profile_type_against_file(
	'Building a COMPASS model with type "compass_wp_dummy_1st" generates the expected file',
	'compass_wp_dummy_1st',
	$alignment_file,
	$compass_prof_types_dir->child( '1.10.150.120__1767.compass_wp_dummy_1st.prof' ),
);

cmp_compass_profile_type_against_file(
	'Building a COMPASS model with type "compass_wp_dummy_2nd" generates the expected file',
	'compass_wp_dummy_2nd',
	$alignment_file,
	$compass_prof_types_dir->child( '1.10.150.120__1767.compass_wp_dummy_2nd.prof' ),
);

cmp_compass_profile_type_against_file(
	'Building a COMPASS model with type "mk_compass_db" generates the expected file',
	'mk_compass_db',
	$alignment_file,
	$compass_prof_types_dir->child( '1.10.150.120__1767.mk_compass_db.prof'        ),
);

