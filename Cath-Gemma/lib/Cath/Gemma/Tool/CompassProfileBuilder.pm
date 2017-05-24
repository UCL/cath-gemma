package Cath::Gemma::Tool::CompassProfileBuilder;

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
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Types  qw/
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 build_compass_profile

=cut

sub build_compass_profile {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, Path, Optional[Path] );
	my ( $class, $exes, $aln_file, $dest_dir, $tmp_dir ) = $check->( @ARG );
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

			my $compass_build_exe = $exes->compass_build();

			my @compass_params = (
				'-g',  '0.50001',
				'-i',  $aln_file,
				'-j',  $tmp_dummy_aln_file,
				'-p1', $tmp_prof_file,
				'-p2', $tmp_dummy_prof_file,
			);

			INFO 'About to build    COMPASS profile for ' . $output_stem;

			my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
				system( "$compass_build_exe", @compass_params );
			};

			if ( $compass_exit != 0 ) {
				confess
					"COMPASS profile-building command "
					.join( ' ', ( "$compass_build_exe", @compass_params ) )
					." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
			}

			INFO 'Finished building COMPASS profile for ' . $output_stem;

			my ( $sed_stdout, $sed_stderr, $sed_exit ) = capture {
				system( 'sed', '-i', '2s/^.*/#/', "$tmp_prof_file" );
			};

			if ( $sed_exit || $sed_stdout || $sed_stderr ) {
				confess "Cannot run sed to standardise second comment line of COMPASS profile file \"$tmp_prof_file\"";
			}

			return {};
		}
	);
}


=head2 build_alignment_and_compass_profile

=cut

sub build_alignment_and_compass_profile {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskProfileDirSet, Optional[Path] );
	my ( $class, $exes, $starting_clusters, $profile_dir_set, $tmp_dir ) = $check->( @ARG );
	$tmp_dir //= $profile_dir_set->aln_dir();

	my $aln_file = $profile_dir_set->alignment_filename_of_starting_clusters( $starting_clusters );
	my $temp_aln_dir = Path::Tiny->tempdir( TEMPLATE => "aln_tempdir.XXXXXXXXXXX", DIR => $tmp_dir );
	my $alignment_result = 
		( -s $aln_file )
		? {
			out_filename => $aln_file
		}
		: Cath::Gemma::Tool::Aligner->make_alignment_file(
			$exes,
			$starting_clusters,
			$profile_dir_set,
			$tmp_dir
		);

	my $built_aln_file   = $alignment_result->{ out_filename  };
	my $profile_result   = Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile(
		$exes,
		$built_aln_file,
		$profile_dir_set->prof_dir,
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
		( defined( $alignment_result->{ duration          } ) ? ( aln_duration          => $alignment_result->{ duration         } ) : () ),
		( defined( $alignment_result->{ mean_seq_length   } ) ? ( mean_seq_length       => $alignment_result->{ mean_seq_length    } ) : () ),
		( defined( $alignment_result->{ num_sequences     } ) ? ( num_sequences         => $alignment_result->{ num_sequences    } ) : () ),
		( defined( $alignment_result->{ wrapper_duration  } ) ? ( aln_wrapper_duration  => $alignment_result->{ wrapper_duration } ) : () ),

		( defined( $profile_result  ->{ duration          } ) ? ( prof_duration         => $profile_result  ->{ duration         } ) : () ),
		( defined( $profile_result  ->{ wrapper_duration  } ) ? ( prof_wrapper_duration => $profile_result  ->{ wrapper_duration } ) : () ),
		aln_filename  => $aln_file,
		prof_filename => $profile_result->{ out_filename  },
	};
}

1;