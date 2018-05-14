package Cath::Gemma::Tool::HHSuiteProfileBuilder;

=head1 NAME

Cath::Gemma::Tool::HHSuiteProfileBuilder - Build a HH-suite profile (.a3m) from alignment (.aln)

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

TODOCUMENT

=cut

sub _run_hhconsensus {
	state $check = compile( ArrayRef[Str], Str );
	my ( $cmd_parts, $output_stem ) = $check->( @ARG );

	INFO 'About to build HH-suite profile for cluster ' . $output_stem;
	DEBUG 'About to run command: ' . join( ' ', @$cmd_parts );

	my ( $stdout, $stderr, $exit ) = capture {
		system( @$cmd_parts );
	};

	if ( $exit != 0 ) {
		confess
			"HH-suite profile building command (for $output_stem) : "
			.join( ' ', @$cmd_parts )
			." failed with:\nstderr:\n$stderr\nstdout:\n$stdout";
	}

	INFO 'Finished building HH-suite profile for cluster ' . $output_stem;
}

=head2 build_profile_in_dir

TODOCUMENT

=cut

sub build_profile_in_dir {
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, Path);
	my ( $class, $exes, $aln_file, $prof_dir ) = $check->( @ARG );

	my $hh_prof_file   = prof_file_of_prof_dir_and_aln_file( $prof_dir, $aln_file, 'hhconsensus' );
	my $output_stem    = $aln_file->basename( alignment_suffix() );

	if ( -s $hh_prof_file ) {
		return {
			file_already_present => 1,
		};
	}

	return run_and_time_filemaking_cmd(
		'HH-suite profile-building',
		$hh_prof_file,
		sub {
			my $prof_atomic_file = shift;
			my $tmp_prof_file    = path( $prof_atomic_file->filename );
			my $tmp_prof_absfile = $tmp_prof_file->absolute();

			# The filename gets written into the profile so nice to make it local...
			my $changed_directory_guard = cwd_guard( ''. $aln_file->parent->absolute() );

			_run_hhconsensus(
				[
					'' . $exes->hhconsensus(),
					'-v', 0,
					'-i', ''.$aln_file,
					'-o', ''.$tmp_prof_absfile,
				],
				$output_stem,
			);

			if ( ! -s $tmp_prof_absfile ) {
				confess "Couldn't find non-empty profile file \"$tmp_prof_absfile\"";
			}

			{
				my ($stdout, $stderr, $exit) 
					= capture { system( "sed -i '1s/.*/#$output_stem/' $tmp_prof_absfile" ); };
				confess "Error when trying to change first line of HH consensus profile:\nSTDOUT: $stdout\n\nSTDERR: $stderr\n" 
					if $exit != 0;
			}

			{
				my ($stdout, $stderr, $exit) 
					= capture { system( "sed -i '2s/.*/>$output_stem _consensus/' $tmp_prof_absfile" ); };
				confess "Error when trying to change second line of HH consensus profile:\nSTDOUT: $stdout\n\nSTDERR: $stderr\n" 
					if $exit != 0;
			}

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
	state $check = compile( ClassName, CathGemmaDiskExecutables, Path, CathGemmaDiskProfileDirSet );
	my ( $class, $exes, $aln_file, $profile_dir_set ) = $check->( @ARG );

	return $class->build_profile_in_dir(
		$exes,
		$aln_file,
		$profile_dir_set->prof_dir(),
	);
}

1;