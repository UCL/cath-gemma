package Cath::Gemma::Tool::HHSuiteScanner;

=head1 NAME

Cath::Gemma::Tool::HHSuiteScanner - Scan HH-suite profiles against libraries of others and store the results in a file

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                  /;
use English             qw/ -no_match_vars           /;
use File::Copy          qw/ copy move                /;
use FindBin;
use Time::HiRes         qw/ gettimeofday tv_interval /;
use v5.10;

# Non-core (local)
use Capture::Tiny       qw/ capture                  /;
use Log::Log4perl::Tiny qw/ :easy                    /;
use Path::Tiny;
use Type::Params        qw/ compile                  /;
use Types::Path::Tiny   qw/ Path                     /;
use Types::Standard     qw/ ArrayRef ClassName Str   /;

# Cath::Gemma
use Cath::Gemma::Scan::ScanData;
use Cath::Gemma::Types  qw/
	CathGemmaHHSuiteProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

use Moo;
with 'Cath::Gemma::Tool::ScannerInterface';

=head2 _ffindex_impl

TODOCUMENT

=cut

sub _ffindex_impl {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path );
	my ( $class, $exes, $prof_lib_file ) = $check->( @ARG );

	my $ffindex_build_exe = $exes->ffindex_build();

	my @ffindex_args = ("-as", "$prof_lib_file.ffdata", "$prof_lib_file.ffindex", "$prof_lib_file" );
	my ( $ffindex_stdout, $ffindex_stderr, $ffindex_exit ) = capture {
		system( "$ffindex_build_exe", @ffindex_args );
	};

	if ( $ffindex_exit != 0 ) {
		confess
			"HHSuite ffindex command "
			.join( ' ', ( "$ffindex_build_exe", @ffindex_args ) )
			." failed with:\nstderr:\n$ffindex_stderr\nstdout:\n$ffindex_stdout";
	}

	return 1;
}

=head2 _hhsearch_scan_impl

TODOCUMENT

=cut

sub _hhsearch_scan_impl {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $profile_build_type ) = $check->( @ARG );

	my $num_query_ids = scalar( @$query_cluster_ids );
	my $num_match_ids = scalar( @$match_cluster_ids );

	Cath::Gemma::Util::check_all_profile_files_exist(
		$profile_dir,
		$query_cluster_ids,
		$match_cluster_ids,
		$profile_build_type
	);

	INFO sprintf "About to build query profile library: profile_dir=%s clusters=[%s] tmp_dir=%s profile_type=%s", $profile_dir, join(",",@$match_cluster_ids), $exes->tmp_dir(), $profile_build_type;
	my $query_prof_lib = build_temp_profile_lib_file( $profile_dir, $query_cluster_ids, $exes->tmp_dir(), $profile_build_type );

	INFO sprintf "About to build match profile library: profile_dir=%s clusters=[%s] tmp_dir=%s profile_type=%s", $profile_dir, join(",",@$match_cluster_ids), $exes->tmp_dir(), $profile_build_type;
	my $match_prof_lib = build_temp_profile_lib_file( $profile_dir, $match_cluster_ids, $exes->tmp_dir(), $profile_build_type );

	my $query_clusters_id = generic_id_of_clusters( $query_cluster_ids, 1 );
	my $match_clusters_id = generic_id_of_clusters( $match_cluster_ids, 1 );

	if ( 0 ) {
		my $query_prof_file_orig = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $query_cluster_ids, $profile_build_type );

		# TODO:
		INFO "COPY $query_prof_file_orig, $query_prof_lib";
		copy( $query_prof_file_orig, $query_prof_lib )
			or confess "failed to copy query alignment ($query_prof_file_orig => $query_prof_lib): $!";
	}

	INFO "QUERY FILE EXISTS: $query_prof_lib ? " . (-e $query_prof_lib ? 'YES' : 'NO');

	INFO "About to index match library HHSuite-[$profile_build_type]-scan     $match_clusters_id [$num_match_ids profile(s)] => $match_prof_lib";

	$class->_ffindex_impl( $exes, $match_prof_lib );

	my $hhsearch_scan_exe = $exes->hhsearch();

	INFO "About to HHSearch-[$profile_build_type]-scan     $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my @hhsearch_args = ( "-cpu", "4", "-i", "$query_prof_lib", "-d", "$match_prof_lib" );
	my ( $hhsearch_stdout, $hhsearch_stderr, $hhsearch_exit ) = capture {
		system( "$hhsearch_scan_exe", @hhsearch_args );
	};

	INFO "QUERY FILE (STILL) EXISTS: $query_prof_lib ? " . (-e $query_prof_lib ? 'YES' : 'NO');

	if ( $hhsearch_exit != 0 ) {
		confess
			"HHSearch scan command "
			.join( ' ', ( "$hhsearch_scan_exe", @hhsearch_args ) )
			." failed with:\nstderr:\n$hhsearch_stderr\nstdout:\n$hhsearch_stdout";
	}

	INFO "Finished HHSearch-[$profile_build_type]-scanning $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my @output_lines = split( /\n/, $hhsearch_stdout );
	my $expected_num_results = $num_query_ids * $num_match_ids;
	return Cath::Gemma::Scan::ScanData->parse_from_raw_hhsearch_scan_output_lines( \@output_lines, $expected_num_results );
}

=head2 hhsuite_scan

TODOCUMENT

=cut

sub hhsuite_scan {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $profile_build_type ) = $check->( @ARG );

	my $result = run_and_time_filemaking_cmd(
		'HHSuite scan',
		undef,
		sub {
			return _hhsuite_scan_impl(
				$exes,
				$profile_dir,
				$query_cluster_ids,
				$match_cluster_ids,
				$profile_build_type,
			);
		}
	);

	if ( defined( $result->{ duration } ) ) {
		$result->{ scan_duration } = $result->{ duration };
		delete $result->{ duration };
	}
	return $result;
}

=head2 scan_to_file

TODOCUMENT

=cut

sub scan_to_file {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $query_ids, $match_ids, $gemma_dir_set, $profile_build_type ) = $check->( @ARG );

	my $output_file = $gemma_dir_set->scan_filename_of_cluster_ids( $query_ids, $match_ids, $profile_build_type );

	my $result = {};
	my $file_already_present = ( -s $output_file ) ? 1 : 0;
	if ( ! $file_already_present ) {
		$result = run_and_time_filemaking_cmd(
			'HHSearch scan',
			$output_file,
			sub {
				my $scan_atomic_file = shift;
				my $tmp_scan_file    = path( $scan_atomic_file->filename );

				my $result = __PACKAGE__->_hhsearch_scan_impl(
					$exes,
					$gemma_dir_set->prof_dir(),
					$query_ids,
					$match_ids,
					$profile_build_type,
				);

				$result->write_to_file( $tmp_scan_file );
				return { result => $result };
			}
		);
	}

	return defined( $result->{ result } )
		? $result
		: {
			result                    => Cath::Gemma::Scan::ScanData->read_from_file( $output_file ),
			scan_file_already_present => $file_already_present,
		};
}

=head2 build_and_scan_merge_cluster_against_others

TODOCUMENT

=cut

sub build_and_scan_merge_cluster_against_others {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $query_starting_cluster_ids, $match_ids, $gemma_dir_set, $profile_build_type ) = $check->( @ARG );

	my $aln_prof_result = Cath::Gemma::Tool::HHSuiteProfileBuilder->build_alignment_and_profile(
		$exes,
		$query_starting_cluster_ids,
		$gemma_dir_set->profile_dir_set(),
		$profile_build_type,
	);

	my $result = __PACKAGE__->hhsearch_scan_to_file(
		$exes,
		[ id_of_clusters( $query_starting_cluster_ids ) ],
		$match_ids,
		$gemma_dir_set,
		$profile_build_type,
	);
	return {
		%$result,

		( defined( $aln_prof_result->{ aln_file_already_present  } ) ? ( aln_file_already_present  => $aln_prof_result->{ aln_file_already_present  } ) : () ),
		( defined( $aln_prof_result->{ aln_filename              } ) ? ( aln_filename              => $aln_prof_result->{ aln_filename              } ) : () ),
		( defined( $aln_prof_result->{ prof_file_already_present } ) ? ( prof_file_already_present => $aln_prof_result->{ prof_file_already_present } ) : () ),
		( defined( $aln_prof_result->{ prof_filename             } ) ? ( prof_filename             => $aln_prof_result->{ prof_filename             } ) : () ),

	};
}

=head2 get_pair_scan_score

TODOCUMENT

=cut

sub get_pair_scan_score {
	
}

=head2 build_temp_profile_lib_file

TODOCUMENT

=cut

sub build_temp_profile_lib_file {
	state $check = compile( Path, ArrayRef[Str], Path, CathGemmaHHSuiteProfileType );
	my ( $profile_dir, $cluster_ids, $dest_dir, $profile_build_type ) = $check->( @ARG );

	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();
	my $profile_suffix = hhsuite_profile_suffix();

	my $lib_file = Path::Tiny->tempfile( TEMPLATE => '.' . id_of_clusters( $cluster_ids ) . '.XXXXXXXXXXX',
	                                         DIR      => $dest_dir,
	                                         SUFFIX   => $profile_suffix,
	                                         CLEANUP  => $CLEANUP_TMP_FILES,
	                                    );

	if ( ! $CLEANUP_TMP_FILES ) {
		WARN "NOT cleaning up temp profile lib file: $lib_file";
	}

	my $lib_fh = $lib_file->openw()
		or confess "Unable to open profile library file \"$lib_file\" for writing : $OS_ERROR";

	# concatenate files into 

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $profile_build_type );
		my $profile_fh = $profile_file->openr()
			or confess "Unable to open profile file \"$profile_file\" for reading : $OS_ERROR";

		# IS: 11/05/2018 - doesn't look like this would append?!
		# copy( $profile_fh, $lib_fh )
		# 	or confess "Failed to copy profile file \"$profile_file\" to profile library file \"$lib_file\" : $OS_ERROR";

		DEBUG sprintf( "Appending %s profile (cluster %d) '%s' to temp profile file '%s'", $profile_build_type, $cluster_id, $profile_file, $lib_file);
        while (my $line = <$profile_fh>) {
            print $lib_fh $line;
        }
		$profile_fh->close;
	}

	return $lib_file;
}


1;