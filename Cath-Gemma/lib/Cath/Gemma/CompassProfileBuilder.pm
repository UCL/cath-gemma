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

# Cath
use Cath::Gemma::Util;

my $compass_build_exe = "$FindBin::Bin/../tools/compass/compass_wp_245_fixed";

=head2 build_compass_profile

# TODO: Abstract out binary-preparation

=cut

sub build_compass_profile {
	state $check = compile( ClassName, Path, Path, Optional[Path] );
	my ( $class, $aln_file, $dest_dir, $tmp_dir ) = $check->( @ARG );
	$tmp_dir //= $dest_dir;

	my $output_stem = $aln_file->basename( alignment_profile_suffix() );

	return run_and_time_filemaking_cmd(
		'COMPASS profile-building',
		$dest_dir->child( $output_stem . compass_profile_suffix() ),
		sub {
			my $prof_atomic_file = shift;
			my $tmp_prof_file    = path( $prof_atomic_file->filename );

			my $tmp_dummy_aln_file  = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => alignment_profile_suffix(), CLEANUP => 1 );
			my $tmp_dummy_prof_file = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => compass_profile_suffix(),   CLEANUP => 1 );
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

			my @compass_params = (
				'-g',  '0.50001',
				'-i',  $aln_file,
				'-j',  $tmp_dummy_aln_file,
				'-p1', $tmp_prof_file,
				'-p2', $tmp_dummy_prof_file,
			);

			INFO 'About to build    COMPASS profile for ' . $output_stem;

			my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
				system( "$local_compass_build_exe", @compass_params );
			};

			if ( $compass_exit != 0 ) {
				confess
					"COMPASS profile-building command "
					.join( ' ', ( "$local_compass_build_exe", @compass_params ) )
					." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
			}

			INFO 'Finished building COMPASS profile for ' . $output_stem;

			return {};
		}
	);
}


=head2 build_alignment_and_compass_profile

=cut

sub build_alignment_and_compass_profile {
	state $check = compile( ClassName, ArrayRef[Str], Path, Path, Path, Optional[Path] );
	my ( $class, $starting_clusters, $starting_cluster_dir, $aln_dest_dir, $prof_dest_dir, $tmp_dir ) = $check->( @ARG );
	$tmp_dir //= $aln_dest_dir;


	my $aln_file = $aln_dest_dir->child( alignment_filename_of_starting_clusters( $starting_clusters ) );
	my $alignment_result = 
		( -s $aln_file )
		? {
			out_filename => $aln_file
		}
		: Cath::Gemma::Aligner->make_alignment_file(
			$starting_clusters,
			$starting_cluster_dir,
			$tmp_dir,
			$tmp_dir
		);

	my $built_aln_file   = $alignment_result->{ out_filename  };
	my $profile_result   = Cath::Gemma::CompassProfileBuilder->build_compass_profile(
		$built_aln_file,
		$prof_dest_dir,
		$tmp_dir,
	);

	if ( "$built_aln_file" ne "$aln_file" ) {
		my $aln_atomic_file   = File::AtomicWrite->new( { file => "$aln_file" } );
		my $atom_tmp_aln_file = path( $aln_atomic_file->filename );

		move( $built_aln_file, $atom_tmp_aln_file )
			or confess "Cannot move built alignment file \"$built_aln_file\" to atomic temporary \"$atom_tmp_aln_file\" : $OS_ERROR";

		$aln_atomic_file->commit();
	}

	return {
		( defined( $alignment_result->{ duration      } ) ? ( aln_duration  => $alignment_result->{ duration      } ) : () ),
		( defined( $alignment_result->{ num_sequences } ) ? ( num_sequences => $alignment_result->{ num_sequences } ) : () ),
		( defined( $profile_result  ->{ duration      } ) ? ( prof_duration => $profile_result  ->{ duration      } ) : () ),
		aln_filename  => $aln_file,
		prof_filename => $profile_result->{ out_filename  },
	};
}

1;