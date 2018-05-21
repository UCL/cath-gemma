package Cath::Gemma::Tool::HHSuiteScanner;

=head1 NAME

Cath::Gemma::Tool::HHSuiteScanner - Scan HHSuite profiles against libraries of others and store the results in a file

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
use Cath::Gemma::Tool::HHSuiteScanner;

use Moo;
with 'Cath::Gemma::Tool::ScannerInterface';

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

	# search individual query alignments against the library of match profiles
	my @all_scan_data;
	for my $query_cluster_id ( @$query_cluster_ids ) {

		my $query_prof_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $query_cluster_id, $profile_build_type );

		# builds profile library db (stub, ffdata, ffindex) from the cluster ids 
		# my ($query_lib_stub, $query_lib_ffdata, $query_lib_ffindex) 
		# 	= build_temp_profile_lib_files( $profile_dir, $exes, $query_cluster_ids, $exes->tmp_dir(), $profile_build_type );
		my ($match_lib_stub, $match_lib_ffdata, $match_lib_ffindex) 
			= build_temp_profile_lib_files( $profile_dir, $exes, $match_cluster_ids, $exes->tmp_dir(), $profile_build_type );

		my $hhsuite_scan_exe = $exes->hhsearch;

		my $query_clusters_id = generic_id_of_clusters( $query_cluster_ids, 1 );
		my $match_clusters_id = generic_id_of_clusters( $match_cluster_ids, 1 );

		# hhsearch -cpu 4 -i $cluster_id.a3m -d $db_stub -o $result_file

		my @scan_command = (
			'-i', $query_prof_file,
			'-d', $match_lib_stub,
		);

		INFO "About to HHSuite-[$profile_build_type]-scan     $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

		my ( $stdout, $stderr, $exit ) = capture {
			system( "$hhsuite_scan_exe", @scan_command );
		};

		if ( $exit != 0 ) {
			confess
				"HHSuite scan command "
				.join( ' ', ( "$hhsuite_scan_exe", @scan_command ) )
				." failed with:\nstderr:\n$stderr\nstdout:\n$stdout";
		}

		INFO "Finished HHSuite-[$profile_build_type]-scanning $query_clusters_id [$num_query_ids profile(s)] versus $match_clusters_id [$num_match_ids profile(s)]";

		my @output_lines = split( /\n/, $stdout );
		my $expected_num_results = $num_query_ids * $num_match_ids;

		my $scan = Cath::Gemma::Scan::ScanData->parse_from_raw_hhsearch_scan_output_lines( \@output_lines, $expected_num_results );

		push @all_scan_data, @{ $scan->scan_data };
	}
	return Cath::Gemma::Scan::ScanData->new( scan_data => \@all_scan_data );
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
			'HHSuite scan',
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

	my $result = __PACKAGE__->scan_to_file(
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

=head2 build_temp_profile_lib_files

Create a hhsuite profile library out of the individual profiles for the given cluster ids 

Effectively this involves:

	ffindex_build: *.a3m -> .ffdata, .ffindex

=cut

sub build_temp_profile_lib_files {
	state $check = compile( Path, CathGemmaDiskExecutables, ArrayRef[Str], Path, CathGemmaHHSuiteProfileType );
	my ( $profile_dir, $exes, $cluster_ids, $dest_dir, $profile_build_type ) = $check->( @ARG );

	my $exe_ffindex_build = $exes->ffindex_build;
	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();

	my $hhsuite_ffdata_suffix  = hhsuite_ffdata_suffix();
	my $hhsuite_ffindex_suffix = hhsuite_ffindex_suffix();
	my $hhsuite_ffdb_suffix    = hhsuite_ffdb_suffix();

	my $ffdata_tmp_file = Path::Tiny->tempfile( TEMPLATE => '.' . id_of_clusters( $cluster_ids ) . '.XXXXXXXXXXX',
	                                         DIR      => $dest_dir,
	                                         CLEANUP  => $CLEANUP_TMP_FILES,
	                                         );

	my $ffbase_file  = path( $ffdata_tmp_file )->absolute;
	my $ffdata_file  = path( $ffbase_file . $hhsuite_ffdata_suffix );
	my $ffdb_file    = path( $ffbase_file . $hhsuite_ffdb_suffix );
	my $ffindex_file = path( $ffbase_file . $hhsuite_ffindex_suffix );
	my $ffprof_list_file = path( $ffbase_file . '.list' );

	# dump the list of profile file paths into a file

	my $ffprof_list_fh   = $ffprof_list_file->openw 
		or confess "failed to open $ffprof_list_file for writing: $!";

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $profile_build_type );
		$ffprof_list_fh->print( $profile_file->absolute, "\n" );
	}
	$ffprof_list_fh->close;

	my @ffindex_args = ( "-as", "-f", $ffprof_list_file, $ffdata_file, $ffindex_file );
	INFO( sprintf "About to ffindex %s profiles for %d cluster ids [%s]: `%s`", $profile_build_type, scalar @$cluster_ids, join( ',', @$cluster_ids ), 
		join( " ", $exe_ffindex_build, @ffindex_args ),
	);

	my ($stdout, $stderr, $exit) = capture {
		system( $exe_ffindex_build, @ffindex_args );
	};

	if ( $exit != 0 ) {
		confess "error: ffindex returned non-zero exit code ($exit)\nCOM: $exe_ffindex_build ".join(" ", @ffindex_args)."\nSTDOUT: $stdout\nSTDERR: $stderr\n";
	}

	if ( !-e $ffdata_file ) {
		confess "failed to create ffdata file $ffdata_file"
	}
	if ( !-e $ffindex_file ) {
		confess "failed to create ffindex file $ffindex_file";
	}

	_register_temp_files( $ffdata_tmp_file, $ffdata_file, $ffindex_file );

	if ( ! $CLEANUP_TMP_FILES ) {
		WARN "NOT cleaning up temp profile lib files: $ffdata_file, $ffindex_file";
	}

	return ( $ffdb_file, $ffdata_file, $ffindex_file );
}

my @ALL_TEMP_FILES;
sub _register_temp_files {
	push @ALL_TEMP_FILES, @_;
}

sub DESTROY {
	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();
	warn "This is where I would consider deleting the following files (CLEANUP=$CLEANUP_TMP_FILES):\n"
		. join( "", map { "\t$_\n" } @ALL_TEMP_FILES );  
}

1;
