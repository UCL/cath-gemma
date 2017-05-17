package Cath::Gemma::CompassScanner;

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
use Cath::Gemma::Util;

my $compass_scan_exe = "$FindBin::Bin/../tools/compass/compass_db1Xdb2_241";

=head2 build_profile_lib_file

=cut

sub build_profile_lib_file {
	state $check = compile( ClassName, Path, ArrayRef[Str], Path );
	my ( $class, $profile_dir, $cluster_ids, $dest_dir ) = $check->( @ARG );

	my $lib_filename = $dest_dir->child( id_of_starting_clusters( $cluster_ids )  . '.prof_lib' );
	my $lib_fh = $lib_filename->openw()
		or confess "Unable to open profile library file \"$lib_filename\" for writing : $OS_ERROR";

	foreach my $cluster_id ( @$cluster_ids ) {
		my $profile_file = $profile_dir->child( $cluster_id . '.faa.prof' );
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
	state $check = compile( ClassName, Path, ArrayRef[Str], ArrayRef[Str], Path );
	my ( $class, $profile_dir, $query_cluster_ids, $match_cluster_ids, $tmp_dir ) = $check->( @ARG );

	my $query_prof_lib = Cath::Gemma::CompassScanner->build_profile_lib_file( $profile_dir, $query_cluster_ids, $tmp_dir );
	my $match_prof_lib = Cath::Gemma::CompassScanner->build_profile_lib_file( $profile_dir, $match_cluster_ids, $tmp_dir );

	my $local_exe_dir   = path( '/dev/shm' );
	my $local_compass_scan_exe = $local_exe_dir->child( path( $compass_scan_exe )->basename() );
	if ( ( -s $compass_scan_exe ) != ( -s $local_exe_dir ) ) {
		copy( $compass_scan_exe, $local_compass_scan_exe )
			or confess "Unable to copy COMPASS executable $compass_scan_exe to local executable $local_compass_scan_exe : $OS_ERROR";
	}
	if ( ! -x $local_compass_scan_exe->stat() ) {
		$local_compass_scan_exe->chmod( 'a+x' )
			or confess "Unable to chmod local COMPASS profile build executable \"$local_compass_scan_exe\" : $OS_ERROR";
	}

	my @compass_scan_command = (
		'-g', '0.50001',
		'-i', $query_prof_lib,
		'-j', $match_prof_lib,
		'-n', '0',
	);

	INFO "About to scan COMPASS profile";

	my $compass_scan_t0 = [ gettimeofday() ];
	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
	  system( "$compass_scan_exe", @compass_scan_command );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS scan command "
			.join( ' ', ( "$compass_scan_exe", @compass_scan_command ) )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	my $compass_scan_duration = tv_interval ( $compass_scan_t0, [ gettimeofday() ] );
	INFO 'Finished scanning COMPASS profile in ' . $compass_scan_duration . 's';

	my ( @outputs, $last_id1, $last_id2 );
	my @scan_lines = split( /\n/, $compass_stdout );
	foreach my $scan_line ( @scan_lines ) {
		if ( $scan_line =~ /^Ali1:\s+(\S+)\s+Ali2:\s+(\S+)/ ) {
			if ( defined( $last_id1 ) || defined( $last_id2 ) ) {
				confess "Argh:\n\"$scan_line\"\n$last_id1\n$last_id2\n";
			}
			$last_id1 = $1;
			$last_id2 = $2;
			foreach my $last_id ( \$last_id1, \$last_id2 ) {
				if ( $$last_id =~ /\/(\w+)\.faa$/ ) {
					$$last_id = $1;
				}
				else {
					confess "Argh $$last_id";
				}
			}
		}
		if ( $scan_line =~ /\bEvalue (.*)$/ ) {
			if ( $1 ne '** not found **' ) {
				if ( $scan_line =~ /\bEvalue = (\S+)$/ ) {
					push @outputs, [ $last_id1, $last_id2, $1 ];
				}
				else {
					confess "Argh";
				}
			}
			if ( ! defined( $last_id1 ) || ! defined( $last_id2 ) ) {
				confess "Argh";
			}
			$last_id1 = undef;
			$last_id2 = undef;
		}
	}

	return \@outputs;
}

1;