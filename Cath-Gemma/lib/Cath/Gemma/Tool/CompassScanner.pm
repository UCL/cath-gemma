package Cath::Gemma::Tool::CompassScanner;

=head1 NAME

Cath::Gemma::Tool::CompassScanner - Scan COMPASS profiles against libraries of others and store the results in a file

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
	CathGemmaCompassProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

use Moo;
with 'Cath::Gemma::Tool::ScannerInterface';


=head2 _compass_scan_impl

TODOCUMENT

=cut

sub _compass_scan_impl {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $compass_profile_build_type ) = $check->( @ARG );

	my $num_query_ids = scalar( @$query_cluster_ids );
	my $num_match_ids = scalar( @$match_cluster_ids );

	Cath::Gemma::Util::check_all_profile_files_exist(
		$profile_dir,
		$query_cluster_ids,
		$match_cluster_ids,
		$compass_profile_build_type
	);

	# builds a profile file from the cluster ids 
	my $query_prof_lib = build_temp_profile_lib_file( $profile_dir, $query_cluster_ids, $exes->tmp_dir(), $compass_profile_build_type );
	my $match_prof_lib = build_temp_profile_lib_file( $profile_dir, $match_cluster_ids, $exes->tmp_dir(), $compass_profile_build_type );

	my $compass_scan_exe =
		( $compass_profile_build_type eq 'mk_compass_db' )
		? $exes->compass_scan_310()
		: $exes->compass_scan_241();

	my $query_clusters_id = generic_id_of_clusters( $query_cluster_ids, 1 );
	my $match_clusters_id = generic_id_of_clusters( $match_cluster_ids, 1 );

	# Note, these commands used to include arguments `-g', '0.50001`, which were inherited from
	# the DFX code. See the commit that introduces this comment for more info.
	my @compass_scan_command = (
		'-i', $query_prof_lib,
		'-j', $match_prof_lib,
		'-n', '0',
	);

	INFO "About to COMPASS-[$compass_profile_build_type]-scan     $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
		system( "$compass_scan_exe", @compass_scan_command );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS scan command "
			.join( ' ', ( "$compass_scan_exe", @compass_scan_command ) )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	INFO "Finished COMPASS-[$compass_profile_build_type]-scanning $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my @compass_output_lines = split( /\n/, $compass_stdout );
	my $expected_num_results = $num_query_ids * $num_match_ids;
	return Cath::Gemma::Scan::ScanData->parse_from_raw_compass_scan_output_lines( \@compass_output_lines, $expected_num_results );
}

=head2 compass_scan

TODOCUMENT

=cut

sub compass_scan {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $compass_profile_build_type ) = $check->( @ARG );

	my $result = run_and_time_filemaking_cmd(
		'COMPASS scan',
		undef,
		sub {
			return _compass_scan_impl(
				$exes,
				$profile_dir,
				$query_cluster_ids,
				$match_cluster_ids,
				$compass_profile_build_type,
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
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $query_ids, $match_ids, $gemma_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	my $output_file = $gemma_dir_set->scan_filename_of_cluster_ids( $query_ids, $match_ids, $compass_profile_build_type );

	my $result = {};
	my $file_already_present = ( -s $output_file ) ? 1 : 0;
	if ( ! $file_already_present ) {
		$result = run_and_time_filemaking_cmd(
			'COMPASS scan',
			$output_file,
			sub {
				my $scan_atomic_file = shift;
				my $tmp_scan_file    = path( $scan_atomic_file->filename );

				my $result = __PACKAGE__->_compass_scan_impl(
					$exes,
					$gemma_dir_set->prof_dir(),
					$query_ids,
					$match_ids,
					$compass_profile_build_type,
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
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $query_starting_cluster_ids, $match_ids, $gemma_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	my $aln_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_profile(
		$exes,
		$query_starting_cluster_ids,
		$gemma_dir_set->profile_dir_set(),
		$compass_profile_build_type,
	);

	my $result = __PACKAGE__->compass_scan_to_file(
		$exes,
		[ id_of_clusters( $query_starting_cluster_ids ) ],
		$match_ids,
		$gemma_dir_set,
		$compass_profile_build_type,
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

Create a compass profile library out of the individual profiles for the given cluster ids 

Effectively this concatenates *.prof -> *.prof_lib

=cut

sub build_temp_profile_lib_file {
	state $check = compile( Path, ArrayRef[Str], Path, CathGemmaCompassProfileType );
	my ( $profile_dir, $cluster_ids, $dest_dir, $profile_build_type ) = $check->( @ARG );

	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();

	my $lib_file = Path::Tiny->tempfile( TEMPLATE => '.' . id_of_clusters( $cluster_ids ) . '.XXXXXXXXXXX',
	                                         DIR      => $dest_dir,
	                                         SUFFIX   => '.prof_lib',
	                                         CLEANUP  => $CLEANUP_TMP_FILES,
	                                         );

	if ( ! $CLEANUP_TMP_FILES ) {
		WARN "NOT cleaning up temp profile lib file: $lib_file";
	}

	my $lib_fh = $lib_file->openw()
		or confess "Unable to open profile library file \"$lib_file\" for writing : $OS_ERROR";

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $profile_build_type );
		my $profile_fh = $profile_file->openr()
			or confess "Unable to open profile file \"$profile_file\" for reading : $OS_ERROR";

		copy( $profile_fh, $lib_fh )
			or confess "Failed to copy profile file \"$profile_file\" to profile library file \"$lib_file\" : $OS_ERROR";
	}

	return $lib_file;
}

1;
