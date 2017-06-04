package Cath::Gemma::Tool::CompassScanner;

use strict;
use warnings;

# Core
use Carp                qw/ confess                         /;
use English             qw/ -no_match_vars                  /;
use File::Copy          qw/ copy move                       /;
use FindBin;
use Time::HiRes         qw/ gettimeofday tv_interval        /;
use v5.10;

# Non-core (local)
use Capture::Tiny       qw/ capture                         /;
use Log::Log4perl::Tiny qw/ :easy                           /;
use Path::Tiny;
use Type::Params        qw/ compile                         /;
use Types::Path::Tiny   qw/ Path                            /;
use Types::Standard     qw/ ArrayRef ClassName Optional Str /;

# Cath
use Cath::Gemma::Scan::ScanData;
use Cath::Gemma::Types  qw/
	CathGemmaDiskExecutables
	CathGemmaDiskGemmaDirSet
/;
use Cath::Gemma::Util;

=head2 _compass_scan_impl

=cut

sub _compass_scan_impl {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], Path );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $tmp_dir ) = $check->( @ARG );
	
	my $num_query_ids = scalar( @$query_cluster_ids );
	my $num_match_ids = scalar( @$match_cluster_ids );

	my $query_prof_lib = __PACKAGE__->build_temp_profile_lib_file( $profile_dir, $query_cluster_ids, $tmp_dir );
	my $match_prof_lib = __PACKAGE__->build_temp_profile_lib_file( $profile_dir, $match_cluster_ids, $tmp_dir );

	my $compass_scan_exe = $exes->compass_scan();

	my $query_clusters_id = generic_id_of_clusters( $query_cluster_ids, 1 );
	my $match_clusters_id = generic_id_of_clusters( $match_cluster_ids, 1 );

	my @compass_scan_command = (
		'-g', '0.50001',
		'-i', $query_prof_lib,
		'-j', $match_prof_lib,
		'-n', '0',
	);

	INFO "About to COMPASS-scan $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
		system( "$compass_scan_exe", @compass_scan_command );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS scan command "
			.join( ' ', ( "$compass_scan_exe", @compass_scan_command ) )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	INFO "Finished COMPASS-scanning $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

	my @compass_output_lines = split( /\n/, $compass_stdout );
	my $expected_num_results = $num_query_ids * $num_match_ids;
	return Cath::Gemma::Scan::ScanData->parse_from_raw_compass_scan_output_lines( \@compass_output_lines, $expected_num_results );
}

=head2 build_temp_profile_lib_file

=cut

sub build_temp_profile_lib_file {
	state $check = compile( ClassName, Path, ArrayRef[Str], Path );
	my ( $class, $profile_dir, $cluster_ids, $dest_dir ) = $check->( @ARG );

	my $lib_filename = Path::Tiny->tempfile( TEMPLATE => '.' . id_of_starting_clusters( $cluster_ids ) . '.XXXXXXXXXXX',
	                                         DIR      => $dest_dir,
	                                         SUFFIX   => '.prof_lib',
	                                         CLEANUP  => 1,
	                                         );
	my $lib_fh = $lib_filename->openw()
		or confess "Unable to open profile library file \"$lib_filename\" for writing : $OS_ERROR";

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = $profile_dir->child( $cluster_id . compass_profile_suffix() );
		my $profile_fh = $profile_file->openr()
			or confess "Unable to open profile file \"$profile_file\" for reading : $OS_ERROR";
		copy( $profile_fh, $lib_fh )
			or confess "Failed to copy profile file \"$profile_file\" to profile library file \"$lib_filename\" : $OS_ERROR";
	}

	return $lib_filename;
}

=head2 compass_scan

=cut

sub compass_scan {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, ArrayRef[Str], ArrayRef[Str], Path );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $tmp_dir ) = $check->( @ARG );

	return run_and_time_filemaking_cmd(
		'COMPASS scan',
		undef,
		sub {
			return _compass_scan_impl(
				$exes,
				$profile_dir,
				$query_cluster_ids,
				$match_cluster_ids,
				$tmp_dir
			);
		}
	);
}

=head2 compass_scan_to_file

=cut

sub compass_scan_to_file {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, Optional[Path] );
	my ( $class, $exes, $query_ids, $match_ids, $gemma_dir_set, $tmp_dir ) = $check->( @ARG );

	$tmp_dir //= $gemma_dir_set->scan_dir;

	my $output_file = $gemma_dir_set->scan_filename_of_cluster_ids( $query_ids, $match_ids );

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
				$tmp_dir
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

=cut

sub build_and_scan_merge_cluster_against_others {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], ArrayRef[Str], CathGemmaDiskGemmaDirSet, Optional[Path] );
	my ( $class, $exes, $query_starting_cluster_ids, $match_ids, $gemma_dir_set, $tmp_dir ) = $check->( @ARG );

	my $build_aln_and_prof_result = Cath::Gemma::Tool::CompassProfileBuilder->build_alignment_and_compass_profile(
		$exes,
		$query_starting_cluster_ids,
		$gemma_dir_set->profile_dir_set(),
		$tmp_dir
	);

	return __PACKAGE__->compass_scan_to_file(
		$exes,
		[ id_of_starting_clusters( $query_starting_cluster_ids ) ],
		$match_ids,
		$gemma_dir_set,
		$tmp_dir
	);
}

1;