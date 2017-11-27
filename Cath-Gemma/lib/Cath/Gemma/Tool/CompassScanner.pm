package Cath::Gemma::Tool::CompassScanner;

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

# Cath
use Cath::Gemma::Scan::ScanData;
use Cath::Gemma::Types  qw/
	CathGemmaCompassProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 _check_all_profile_files_exist

TODOCUMENT

=cut

sub _check_all_profile_files_exist {
	state $check = compile( ClassName, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $class, $profile_dir, $query_cluster_ids, $match_cluster_ids, $compass_profile_build_type ) = $check->( @ARG );

	foreach my $cluster_id ( @$query_cluster_ids, @$match_cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $compass_profile_build_type );
		if ( ! -s $profile_file ) {
			confess "Unable to find non-empty profile file $profile_file for cluster $cluster_id when scanning queries ("
			        . join( ', ', @$query_cluster_ids )
			        . ') against matches ('
			        . join( ', ', @$match_cluster_ids )
			        . ')';
		}
	}
}

=head2 _compass_scan_impl

TODOCUMENT

=cut

sub _compass_scan_impl {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $compass_profile_build_type ) = $check->( @ARG );

	my $num_query_ids = scalar( @$query_cluster_ids );
	my $num_match_ids = scalar( @$match_cluster_ids );

	$class->_check_all_profile_files_exist(
		$profile_dir,
		$query_cluster_ids,
		$match_cluster_ids,
		$compass_profile_build_type
	);

	my $query_prof_lib = __PACKAGE__->build_temp_profile_lib_file( $profile_dir, $query_cluster_ids, $exes->tmp_dir(), $compass_profile_build_type );
	my $match_prof_lib = __PACKAGE__->build_temp_profile_lib_file( $profile_dir, $match_cluster_ids, $exes->tmp_dir(), $compass_profile_build_type );

	my $compass_scan_exe =
		( $compass_profile_build_type eq 'mk_compass_db' )
		? $exes->compass_scan_310()
		: $exes->compass_scan_241();

	my $query_clusters_id = generic_id_of_clusters( $query_cluster_ids, 1 );
	my $match_clusters_id = generic_id_of_clusters( $match_cluster_ids, 1 );

	my @compass_scan_command = (
		'-g', '0.50001',
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

=head2 build_temp_profile_lib_file

TODOCUMENT

=cut

sub build_temp_profile_lib_file {
	state $check = compile( ClassName, Path, ArrayRef[Str], Path, CathGemmaCompassProfileType );
	my ( $class, $profile_dir, $cluster_ids, $dest_dir, $compass_profile_build_type ) = $check->( @ARG );

	my $lib_filename = Path::Tiny->tempfile( TEMPLATE => '.' . id_of_starting_clusters( $cluster_ids ) . '.XXXXXXXXXXX',
	                                         DIR      => $dest_dir,
	                                         SUFFIX   => '.prof_lib',
	                                         CLEANUP  => 1,
	                                         );
	my $lib_fh = $lib_filename->openw()
		or confess "Unable to open profile library file \"$lib_filename\" for writing : $OS_ERROR";

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $compass_profile_build_type );
		my $profile_fh = $profile_file->openr()
			or confess "Unable to open profile file \"$profile_file\" for reading : $OS_ERROR";
		copy( $profile_fh, $lib_fh )
			or confess "Failed to copy profile file \"$profile_file\" to profile library file \"$lib_filename\" : $OS_ERROR";
	}

	return $lib_filename;
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

=head2 compass_scan_to_file

TODOCUMENT

=cut

sub compass_scan_to_file {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $query_ids, $match_ids, $gemma_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	my $output_file = $gemma_dir_set->scan_filename_of_cluster_ids( $query_ids, $match_ids, $compass_profile_build_type );

	my $result = run_and_time_filemaking_cmd(
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

	return defined( $result->{ result } )
		? $result
		: {
			result => Cath::Gemma::Scan::ScanData->read_from_file( $output_file )
		};
}

=head2 build_and_scan_merge_cluster_against_others

TODOCUMENT

=cut

sub build_and_scan_merge_cluster_against_others {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $query_starting_cluster_ids, $match_ids, $gemma_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
		$exes,
		$query_starting_cluster_ids,
		$gemma_dir_set->profile_dir_set(),
		$compass_profile_build_type,
	);

	return __PACKAGE__->compass_scan_to_file(
		$exes,
		[ id_of_starting_clusters( $query_starting_cluster_ids ) ],
		$match_ids,
		$gemma_dir_set,
		$compass_profile_build_type,
	);
}

=head2 get_pair_scan_score

TODOCUMENT

=cut

sub get_pair_scan_score {
	
}

1;