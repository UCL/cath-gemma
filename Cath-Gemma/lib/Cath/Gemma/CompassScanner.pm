package Cath::Gemma::CompassScanner;

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
use Cath::Gemma::Types  qw/ CathGemmaExecutables            /;
use Cath::Gemma::Util;

=head2 _compass_scan_impl

=cut

sub _compass_scan_impl {
	state $check = compile( ClassName, CathGemmaExecutables, Path, ArrayRef[Str], ArrayRef[Str], Path );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $tmp_dir ) = $check->( @ARG );

	my $query_prof_lib = Cath::Gemma::CompassScanner->build_temp_profile_lib_file( $profile_dir, $query_cluster_ids, $tmp_dir );
	my $match_prof_lib = Cath::Gemma::CompassScanner->build_temp_profile_lib_file( $profile_dir, $match_cluster_ids, $tmp_dir );

	my $compass_scan_exe = $exes->compass_scan();

	my @compass_scan_command = (
		'-g', '0.50001',
		'-i', $query_prof_lib,
		'-j', $match_prof_lib,
		'-n', '0',
	);

	INFO "About to scan COMPASS profile";

	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
		system( "$compass_scan_exe", @compass_scan_command );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS scan command "
			.join( ' ', ( "$compass_scan_exe", @compass_scan_command ) )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	INFO 'Finished scanning COMPASS profile';

	my @compass_output_lines = split( /\n/, $compass_stdout );
	return Cath::Gemma::CompassScanner->_parse_compass_scan_output( \@compass_output_lines );
}

=head2 _parse_compass_scan_output

=cut

sub _parse_compass_scan_output {
	state $check = compile( ClassName, ArrayRef[Str] );
	my ( $class, $compass_output_lines ) = $check->( @ARG );

	my ( @outputs, $prev_id1, $prev_id2 );
	my $alignment_profile_suffix = alignment_profile_suffix();
	foreach my $compass_output_line ( @$compass_output_lines ) {
		if ( $compass_output_line =~ /^Ali1:\s+(\S+)\s+Ali2:\s+(\S+)/ ) {
			if ( defined( $prev_id1 ) || defined( $prev_id2 ) ) {
				confess "Argh:\n\"$compass_output_line\"\n$prev_id1\n$prev_id2\n";
			}
			$prev_id1 = $1;
			$prev_id2 = $2;
			foreach my $prev_id ( \$prev_id1, \$prev_id2 ) {
				if ( $$prev_id =~ /\/(\w+)$alignment_profile_suffix$/ ) {
					$$prev_id = $1;
				}
				else {
					confess "Argh $$prev_id";
				}
			}
		}
		if ( $compass_output_line =~ /\bEvalue (.*)$/ ) {
			if ( $1 ne '** not found **' ) {
				if ( $compass_output_line =~ /\bEvalue = (\S+)$/ ) {
					push @outputs, [ $prev_id1, $prev_id2, $1 ];
				}
				else {
					confess "Argh";
				}
			}
			if ( ! defined( $prev_id1 ) || ! defined( $prev_id2 ) ) {
				confess "Argh";
			}
			$prev_id1 = undef;
			$prev_id2 = undef;
		}
	}

	return \@outputs;
}

=head2 build_temp_profile_lib_file

=cut

sub build_temp_profile_lib_file {
	state $check = compile( ClassName, Path, ArrayRef[Str], Path );
	my ( $class, $profile_dir, $cluster_ids, $dest_dir ) = $check->( @ARG );

	# TODO: Make this a tempfile

	my $lib_filename = $dest_dir->child( id_of_starting_clusters( $cluster_ids )  . '.prof_lib' );
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
	state $check = compile( ClassName, CathGemmaExecutables, Path, ArrayRef[Str], ArrayRef[Str], Path );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $tmp_dir ) = $check->( @ARG );

	return run_and_time_filemaking_cmd(
		'COMPASS scan',
		undef,
		sub {
			return {
				data => Cath::Gemma::CompassScanner->_compass_scan_impl(
					$exes,
					$profile_dir,
					$query_cluster_ids,
					$match_cluster_ids,
					$tmp_dir
				)
			};
		}
	);
}

=head2 compass_scan_to_file

=cut

sub compass_scan_to_file {
	state $check = compile( ClassName, CathGemmaExecutables, Path, ArrayRef[Str], ArrayRef[Str], Path, Optional[Path] );
	my ( $class, $exes, $profile_dir, $query_cluster_ids, $match_cluster_ids, $dest_dir, $tmp_dir ) = $check->( @ARG );
	$tmp_dir //= $dest_dir;

	return run_and_time_filemaking_cmd(
		'COMPASS scan',
		$dest_dir->child( scan_filename_of_cluster_ids( $query_cluster_ids, $match_cluster_ids ) ),
		sub {
			my $scan_atomic_file = shift;
			my $tmp_scan_file    = path( $scan_atomic_file->filename );

			my $result = Cath::Gemma::CompassScanner->_compass_scan_impl(
				$exes,
				$profile_dir,
				$query_cluster_ids,
				$match_cluster_ids,
				$tmp_dir
			);

			$tmp_scan_file->spew( join(
				"\n",
				map {
					join( "\t", @$ARG );
				} @$result
			) . "\n" );
			return {};
		}
	);
}

1;