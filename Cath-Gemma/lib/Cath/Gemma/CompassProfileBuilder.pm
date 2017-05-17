package Cath::Gemma::CompassProfileBuilder;

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

my $compass_build_exe = "$FindBin::Bin/../tools/compass/compass_wp_245_fixed";

=head2 build_compass_profile

=cut

sub build_compass_profile {
	state $check = compile( ClassName, Path, Path, Optional[Path] );
	my ( $class, $aln_file, $dest_dir, $tmp_dir ) = $check->( @ARG );

	my $basename = $aln_file->basename();
	my $dest_prof_filename = $dest_dir->child( $basename . '.prof' );

	$tmp_dir //= $dest_dir;

	if ( -s $dest_prof_filename ) {
		return {
			out_filename => $dest_prof_filename,
		};
	}
	if ( -e $dest_prof_filename ) {
		$dest_prof_filename->remove()
			or confess "Cannot delete empty COMPASS profile file $dest_prof_filename";
	}

	my $tmp_prof_file = Path::Tiny->tempfile( TEMPLATE => '.tmp_prof.' . $basename . '.XXXXXXXXXXX',
	                                          DIR      => $dest_dir,
	                                          SUFFIX   => '.faa',
	                                          CLEANUP  => 1,
	                                          );

	my $tmp_dummy_aln_file  = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => '.faa',  CLEANUP => 1 );
	my $tmp_dummy_prof_file = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => '.prof', CLEANUP => 1 );
	$tmp_dummy_aln_file->spew( "'>A\nA\n" );

	my $local_exe_dir   = path( '/dev/shm' );
	my $local_compass_build_exe = $local_exe_dir->child( path( $compass_build_exe )->basename() );
	if ( ( -s $compass_build_exe ) != ( -s $local_exe_dir ) ) {
		copy( $compass_build_exe, $local_compass_build_exe )
			or confess "Unable to copy COMPASS executable $compass_build_exe to local executable $local_compass_build_exe : $OS_ERROR";
	}
	if ( ! -x $local_compass_build_exe->stat() ) {
		$local_compass_build_exe->chmod( 'a+x' )
			or confess "Unable to chmod local COMPASS profile build executable \"$local_compass_build_exe\" : $OS_ERROR";
	}

	# TODO: Make this write to a temporary file and then rename to dest when finished

	my @compass_params = (
		'-g',  '0.50001',
		'-i',  $aln_file,
		'-j',  $tmp_dummy_aln_file,
		'-p1', $tmp_prof_file,
		'-p2', $tmp_dummy_prof_file,
	);

	INFO "About to build COMPASS profile";

	my $compass_build_t0 = [ gettimeofday() ];
	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
	  system( "$local_compass_build_exe", @compass_params );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS profile-building command "
			.join( ' ', ( "$local_compass_build_exe", @compass_params ) )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	my $compass_build_duration = tv_interval ( $compass_build_t0, [ gettimeofday() ] );
	INFO 'Finished building COMPASS profile in ' . $compass_build_duration . 's';

	if ( ! -e $dest_prof_filename ) {
		move( $tmp_prof_file, $dest_prof_filename );
	}

	return {
		out_filename => $dest_prof_filename,
		(
			defined( $compass_build_duration )
			? ( duration => $compass_build_duration )
			: ()
		),
	};
}

1;