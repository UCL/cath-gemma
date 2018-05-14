#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English             qw/ -no_match_vars /;
use FindBin;
use v5.10;

# Core (test)
use Test::More;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Path::Tiny   qw/ Path           /;
use Types::Standard     qw/ Str            /;

use Test::Trap;

# Find Cath::Gemma::Test lib directory using FindBin (and tidy using Path::Tiny)
use lib path( $FindBin::Bin . '/lib' )->realpath()->stringify();

# Cath Test
use Cath::Gemma::Test;

# Cath::Gemma
use Cath::Gemma::Disk::Executables;
#use Cath::Gemma::Tool::CompassProfileBuilder;
use Cath::Gemma::Util;

# Don't flood this test with INFO messages
Log::Log4perl->easy_init( { level => $WARN } );

my $test_base_dir             = path( $FindBin::Bin . '/data' )->realpath();
my $example_sfam_id           = '3.30.70.1470';

my $starting_clusters_dir     = $test_base_dir->child( "$example_sfam_id/alignments" );
my $build_hhsearch_db_dir     = $test_base_dir->child( "build_hhsearch_db/$example_sfam_id" );
#my $prof_type                 = 'compass_wp_dummy_1st';

my $exe_dir                   = path( "$FindBin::Bin/../tools/hhsuite" )->realpath;
my $exe_hhconsensus           = path( $exe_dir )->child( 'bin/hhconsensus' );
my $exe_hhsearch              = path( $exe_dir )->child( 'bin/hhsearch' );
my $exe_ffindex_build         = path( $exe_dir )->child( 'bin/ffindex_build' );

test_hhsearch_inline( "build and scan clusters with hhsearch (inline)", $starting_clusters_dir, $build_hhsearch_db_dir );

test_hhsearch_lib( "build and scan clusters with hhsearch (using libraries)", $starting_clusters_dir, $build_hhsearch_db_dir );

done_testing;

exit;

=head2 test_hhsearch_lib

TODOCUMENT

=cut

sub test_hhsearch_lib {
	state $check = compile( Str, Path, Path );
	my ( $assertion_name, $aln_dir, $expected_dir ) = $check->( @ARG );

	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.compass_profile_build.XXXXXXXXXXX" );
	my $got_file     = prof_file_of_prof_dir_and_aln_file( $test_out_dir, $aln_file, $prof_type );

	# Build a profile file
	Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
		Cath::Gemma::Disk::Executables->new(),
		$aln_file,
		$test_out_dir,
		$prof_type,
	);

	# Compare it to expected
	file_matches(
		$got_file,
		$expected_prof,
		$assertion_name
	);

}

=head2 test_hhsearch_inline

TODOCUMENT

=cut

sub test_hhsearch_inline {
	state $check = compile( Str, Path, Path );
	my ( $assertion_name, $aln_dir, $expected_dir ) = $check->( @ARG );

	my $test_out_dir = cath_test_tempdir( TEMPLATE => "test.hhsearch_db_build.XXXXXXXXXXX" );

    # 0. env

    $ENV{HHLIB} = $exe_dir;

    # 1. hhconsensus: *.aln -> *.a3m 

    my $a3m_dir = $test_out_dir->child( 'a3m' );
    $a3m_dir->mkpath or die "! Error: failed to create dir $a3m_dir: $1";

    my $max_clusters = 10;
    my @cluster_names;
    my $count=0;
    for my $aln_file ( sort $aln_dir->children ) {
        next unless $aln_file->basename =~ /^([0-9]+?)\.aln$/;
        last if ++$count == $max_clusters;
        my $cluster_name = $1;
        push @cluster_names, $cluster_name;
        my $a3m_file = $a3m_dir->child( $cluster_name . ".a3m" );
        trap { 
            sys( "$exe_hhconsensus -v 0 -i $aln_file -o $a3m_file" );
            sys( "sed -i '1s/.*/#$cluster_name/' $a3m_file" );
            sys( "sed -i '2s/.*/>$cluster_name _consensus/' $a3m_file" );
        };
        ok( -e "$a3m_file", "a3m file exists: $a3m_file" );
    }

    # 2. ffindex_build: *.a3m -> .ffdata, .ffindex

    my $db_dir = $test_out_dir->child( 'db' );
    $db_dir->mkpath or die "! Error: failed to create dir $db_dir: $1";
    trap {
        sys( "$exe_ffindex_build -as $db_dir/db_a3m.ffdata $db_dir/db_a3m.ffindex $a3m_dir" );
    };
    ok( -e "$db_dir/db_a3m.ffdata", "ffdata file exists" );
    ok( -e "$db_dir/db_a3m.ffindex", "ffindex file exists" );

    # 3. hhsearch: search the first cluster against the db
    
    my $example_cluster_id = $cluster_names[0];
    my $result_file = $test_out_dir->child( "result.hhsearch" );
    trap {
        sys( "$exe_hhsearch -cpu 4 -i $a3m_dir/$example_cluster_id.a3m -d $db_dir/db -o $result_file" );
    };
    ok( -e "$result_file", "hhsearch results file exists: $result_file" );

    warn $result_file->slurp;

	# # Build a profile file
	# Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile_in_dir(
	# 	Cath::Gemma::Disk::Executables->new(),
	# 	$aln_file,
	# 	$test_out_dir,
	# 	$prof_type,
	# );

	# # Compare it to expected
	# file_matches(
	# 	$got_file,
	# 	$expected_prof,
	# 	$assertion_name
	# );

}

sub sys {
    my $com = shift;
    diag( "COM: $com" );
    `$com`;
}
