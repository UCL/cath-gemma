package Cath::Gemma::Tool::HHSuiteProfileBuilder;

=head1 NAME

Cath::Gemma::Tool::HHSuiteProfileBuilder - Build a HHSuite profile file

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                              /;
use English             qw/ -no_match_vars                       /;
use File::Copy          qw/ copy move                            /;
use FindBin;
use Time::HiRes         qw/ gettimeofday tv_interval             /;
use v5.10;

# Non-core (local)
use Capture::Tiny       qw/ capture                              /;
use Cwd::Guard          qw/ cwd_guard                            /;
use Log::Log4perl::Tiny qw/ :easy                                /;
use Path::Tiny;
use Try::Tiny;
use Type::Params        qw/ compile                              /;
use Types::Path::Tiny   qw/ Path                                 /;
use Types::Standard     qw/ ArrayRef Bool ClassName Optional Str /;

# Cath::Gemma
use Cath::Gemma::Tool::Aligner;
use Cath::Gemma::Types  qw/
	CathGemmaHHSuiteProfileType
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

use Moo;
with 'Cath::Gemma::Tool::ProfileBuilderInterface';

=head2 _run_hhconsensus

Runs hhconsensus (abstracted mainly for logging purposes)

=cut

sub _run_hhconsensus {
	state $check = compile( ArrayRef[Str], Str, CathGemmaHHSuiteProfileType );
	my ( $cmd_parts, $output_stem, $profile_build_type ) = $check->( @ARG );

	INFO 'About to build    ' . $profile_build_type . ' HHSuite profile for cluster ' . $output_stem;
	DEBUG 'About to run command: ' . join( ' ', @$cmd_parts );

	my ( $stdout, $stderr, $exit ) = capture {
		system( @$cmd_parts );
	};

	if ( $exit != 0 ) {
		confess
			"HHSuite profile-building command (for $output_stem) : "
			.join( ' ', @$cmd_parts )
			." failed with:\nstderr:\n$stderr\nstdout:\n$stdout";
	}

	INFO 'Finished building ' . $profile_build_type . ' HHSuite profile for cluster ' . $output_stem;
}

=head2 build_profile_in_dir

TODOCUMENT

=cut

sub build_profile_in_dir {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, Path, CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $aln_file, $prof_dir, $profile_build_type ) = $check->( @ARG );

	my $prof_file = prof_file_of_prof_dir_and_aln_file( $prof_dir, $aln_file, $profile_build_type );
	my $output_stem = $aln_file->basename( alignment_suffix() );

	if ( -s $prof_file ) {
		return {
			file_already_present => 1,
		};
	}

	return run_and_time_filemaking_cmd(
		'HHSuite profile-building',
		$prof_file,
		sub {
			my $prof_atomic_file = shift;
			my $tmp_prof_file    = path( $prof_atomic_file->filename );
			my $tmp_prof_absfile = $tmp_prof_file->absolute();
			my $tmp_prof_absfile_orig = path( $tmp_prof_absfile . '.orig' );

			# The filename gets written into the profile so nice to make it local...
			my $changed_directory_guard = cwd_guard( ''. $aln_file->parent->absolute() );

			# hhconsensus -v 0 -i $aln_file -o $a3m_file
			_run_hhconsensus(
				[
					'' . $exes->hhconsensus(),
					'-i', ''.$aln_file,
					'-o', ''.$tmp_prof_absfile_orig,
				],
				$output_stem,
				$profile_build_type
			);


			if ( ! -s $tmp_prof_absfile_orig ) {
				confess "Couldn't find non-empty output profile file \"$tmp_prof_absfile_orig\"";
			}

            # sed -i '1s/.*/#$cluster_name/' $a3m_file
            # sed -i '2s/.*/>$cluster_name _consensus/' $a3m_file

			my $fh_in  = $tmp_prof_absfile_orig->openr;
			my $fh_out = $tmp_prof_absfile->openw;
			while ( my $line = <$fh_in> ) {
				if ( $. == 1 ) {
					$line = "#$output_stem\n";
				}
				if ( $. == 2 ) {
					$line = ">$output_stem _consensus\n";
				}
				$fh_out->print( $line );
			}
			$fh_in->close;
			$fh_out->close;

			return {
				file_already_present => 0,
			};
		}
	);
}


=head2 build_profile

TODOCUMENT

=cut

sub build_profile {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, CathGemmaDiskProfileDirSet, CathGemmaHHSuiteProfileType );
	my ( $class, $exes, $aln_file, $profile_dir_set, $profile_build_type ) = $check->( @ARG );

	return __PACKAGE__->build_profile_in_dir(
		$exes,
		$aln_file,
		$profile_dir_set->prof_dir(),
		$profile_build_type,
	);
}

1;