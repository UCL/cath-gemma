package Cath::Gemma::Tool::CompassProfileBuilder;

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
use Cwd::Guard          qw/ cwd_guard                /;
use Log::Log4perl::Tiny qw/ :easy                    /;
use Path::Tiny;
use Try::Tiny;
use Type::Params        qw/ compile                  /;
use Types::Path::Tiny   qw/ Path                     /;
use Types::Standard     qw/ ArrayRef ClassName Str   /;

# Cath::Gemma
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Types  qw/
	CathGemmaCompassProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 _run_compass

TODOCUMENT

=cut

sub _run_compass_build {
	state $check = compile( ArrayRef[Str], Str, CathGemmaCompassProfileType );
	my ( $cmd_parts, $output_stem, $compass_profile_build_type ) = $check->( @ARG );

	INFO 'About to build    ' . $compass_profile_build_type . ' COMPASS profile for cluster ' . $output_stem;
	DEBUG 'About to run command: ' . join( ' ', @$cmd_parts );

	my ( $compass_stdout, $compass_stderr, $compass_exit ) = capture {
		system( @$cmd_parts );
	};

	if ( $compass_exit != 0 ) {
		confess
			"COMPASS profile-building command (for $output_stem) : "
			.join( ' ', @$cmd_parts )
			." failed with:\nstderr:\n$compass_stderr\nstdout:\n$compass_stdout";
	}

	INFO 'Finished building ' . $compass_profile_build_type . ' COMPASS profile for cluster ' . $output_stem;

}

=head2 build_compass_profile_in_dir

TODOCUMENT

=cut

sub build_compass_profile_in_dir {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, Path, CathGemmaCompassProfileType );
	my ( $class, $exes, $aln_file, $prof_dir, $compass_profile_build_type ) = $check->( @ARG );

	my $compass_prof_file = prof_file_of_prof_dir_and_aln_file( $prof_dir, $aln_file, $compass_profile_build_type );
	my $output_stem       = $aln_file->basename( alignment_profile_suffix() );

	if ( -s $compass_prof_file ) {
		return {};
	}

	return run_and_time_filemaking_cmd(
		'COMPASS profile-building',
		$compass_prof_file,
		sub {
			my $prof_atomic_file = shift;
			my $tmp_prof_file    = path( $prof_atomic_file->filename );
			my $tmp_prof_absfile = $tmp_prof_file->absolute();

			# The filename gets written into the profile so nice to make it local...
			my $changed_directory_guard = cwd_guard( ''. $aln_file->parent->absolute() );

			if ( $compass_profile_build_type eq 'mk_compass_db' ) {
				my $tmp_list_file = Path::Tiny->tempfile( DIR => $exes->tmp_dir(), TEMPLATE => '.mk_compass_db.list.XXXXXXXXXXX', SUFFIX => '.txt', CLEANUP => 1 );
				$tmp_list_file->spew( $aln_file->basename() . "\n" );

				_run_compass_build(
					[
						'' . $exes->mk_compass_db(),
						'-g', '0.50001',
						'-i', ''.$tmp_list_file,
						'-o', ''.$tmp_prof_absfile,
					],
					$output_stem,
					$compass_profile_build_type
				);

				my $length_file = $tmp_prof_absfile->sibling( $tmp_prof_absfile->basename() . '.len' );
				if ( ! -s $length_file ) {
					confess "Couldn't find non-empty length file \"$length_file\"";
				}
				$length_file->remove()
					or confess "Unable to remove COMPASS profile \"$length_file\" : $OS_ERROR";
			}
			else {
				my $tmp_dummy_aln_file  = Path::Tiny->tempfile( DIR => $exes->tmp_dir(), TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => alignment_profile_suffix(), CLEANUP => 1 );
				my $tmp_dummy_prof_file = Path::Tiny->tempfile( DIR => $exes->tmp_dir(), TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => compass_profile_suffix(),   CLEANUP => 1 );
				$tmp_dummy_aln_file->spew( ">A\nA\n" );

				my $tmp_dummy_aln_absfile  = $tmp_dummy_aln_file->absolute();
				my $tmp_dummy_prof_absfile = $tmp_dummy_prof_file->absolute();

				_run_compass_build(
					[
						'' . $exes->compass_build(),
						'-g', '0.50001',
						(
							( $compass_profile_build_type eq 'compass_wp_dummy_1st' )
							? (
								# Matches trace_files_from_dfx_run_201705 :
								'-i',  ''.$tmp_dummy_aln_absfile,
								'-j',  ''.$aln_file->basename(),
								'-p1', ''.$tmp_dummy_prof_absfile,
								'-p2', ''.$tmp_prof_absfile,
							)
							: (
								# Almost matches trace_files_from_daves_dirs :
								'-i',  ''.$aln_file->basename(),
								'-j',  ''.$tmp_dummy_aln_absfile,
								'-p1', ''.$tmp_prof_absfile,
								'-p2', ''.$tmp_dummy_prof_absfile,
							)
						)
					],
					$output_stem,
					$compass_profile_build_type
				);

				# If the fourth line is empty, attempt to fix the broken COMPASS profile
				# by removing an extra line
				my @lines_4_and_5  = ( split( /\n/, $tmp_prof_absfile->slurp() ) ) [ 3..4 ];

				my $del_extra_line_a = $lines_4_and_5[ 0 ] !~ /\S/;
				my $del_extra_line_b = $lines_4_and_5[ 1 ] !~ /\S/;

				# Run sed in an attempt to tidy up the COMPASS profile
				my ( $sed_stdout, $sed_stderr, $sed_exit ) = capture {
					system(
						'sed',
						'-i',
						'-e',
						'3i#',
						'-e',
						'2d',
						(
							$del_extra_line_a
							? ( '-e', '3d' )
							: (            )
						),
						(
							$del_extra_line_b
							? ( '-e', '4d' )
							: (            )
						),
						"$tmp_prof_absfile"
					);
				};

				if ( $sed_exit || $sed_stdout || $sed_stderr ) {
					confess "Cannot run sed to standardise second comment line of COMPASS profile file \"$tmp_prof_file\":\n\n$sed_exit\n\n$sed_stdout\n\n$sed_stderr\n\n ";
				}
			}

			return {};
		}
	);
}


=head2 build_compass_profile

TODOCUMENT

=cut

sub build_compass_profile {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, CathGemmaDiskProfileDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $aln_file, $profile_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	return __PACKAGE__->build_compass_profile_in_dir(
		$exes,
		$aln_file,
		$profile_dir_set->prof_dir(),
		$compass_profile_build_type,
	);
}

=head2 build_alignment_and_compass_profile

TODOCUMENT

=cut

sub build_alignment_and_compass_profile {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskProfileDirSet, CathGemmaCompassProfileType );
	my ( $class, $exes, $starting_clusters, $profile_dir_set, $compass_profile_build_type ) = $check->( @ARG );

	my $aln_file = $profile_dir_set->alignment_filename_of_starting_clusters( $starting_clusters );
	my $temp_aln_dir = Path::Tiny->tempdir( TEMPLATE => "aln_tempdir.XXXXXXXXXXX", DIR => $exes->tmp_dir() );
	my $alignment_result = 
		( -s $aln_file )
		? {
			out_filename => $aln_file
		}
		: Cath::Gemma::Tool::Aligner->make_alignment_file(
			$exes,
			$starting_clusters,
			$profile_dir_set,
		);

	my $built_aln_file   = $alignment_result->{ out_filename  };
	my $profile_result   = Cath::Gemma::Tool::CompassProfileBuilder->build_compass_profile(
		$exes,
		$built_aln_file,
		$profile_dir_set,
		$compass_profile_build_type,
	);

	if ( "$built_aln_file" ne "$aln_file" ) {
		my $aln_atomic_file   = File::AtomicWrite->new( { file => "$aln_file" } );
		my $atom_tmp_aln_file = path( $aln_atomic_file->filename );

		move( $built_aln_file, $atom_tmp_aln_file )
			or confess "Cannot move built alignment file \"$built_aln_file\" to atomic temporary \"$atom_tmp_aln_file\" : $OS_ERROR";

		try {
			$aln_atomic_file->commit();
		}
		catch {
			my $error = $ARG;
			while ( chomp( $error ) ) {}
			confess
				   'Caught error when trying to atomically commit write of temporary file "'
				 . $aln_atomic_file->filename()
				 . '" to "'
				 . $aln_file
				 . '", original error message: "'
				 . $error
				 . '".';
		};
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