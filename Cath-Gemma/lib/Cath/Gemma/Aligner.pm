package Cath::Gemma::Aligner;

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
use File::AtomicWrite;
use Log::Log4perl::Tiny qw/ :easy                           /;
use Path::Tiny;
use Type::Params        qw/ compile                         /;
use Types::Path::Tiny   qw/ Path                            /;
use Types::Standard     qw/ ArrayRef ClassName Optional Str /;

# Cath
use Cath::Gemma::Util;

my $mafft_exe = "$FindBin::Bin/../tools/mafft-6.864-without-extensions/core/mafft";

=head2 build_raw_seqs_file

=cut

sub build_raw_seqs_file {
	shift;
	my $starting_clusters    = shift;
	my $starting_cluster_dir = shift;
	my $dest_file            = shift;

	my $dest_fh = $dest_file->openw();

	my $num_sequences = 0;

	foreach my $starting_cluster ( @$starting_clusters ) {
		my $starting_cluster_file = $starting_cluster_dir->child( $starting_cluster . alignment_profile_suffix() );
		if ( ! -s $starting_cluster_file ) {
			confess "Cannot find non-empty starting cluster file \"$starting_cluster_file\"";
		}

		my $starting_cluster_data = $starting_cluster_file->slurp();
		my @starting_cluster_lines = split( /\n/, $starting_cluster_data );
		foreach my $starting_cluster_line ( @starting_cluster_lines ) {
			if ( $starting_cluster_line =~ /^>/ ) {
				++$num_sequences;
			}
			print $dest_fh "$starting_cluster_line\n";
		}
	}

	# TODO: Add in returning the average sequence length
	return {
		num_sequences => $num_sequences
	};
}

=head2 make_alignment_file

# TODO: Abstract out timing, output-existence-checking, binary-preparation

=cut

sub make_alignment_file {
	state $check = compile( ClassName, ArrayRef[Str], Path, Path, Optional[Path] );
	my ( $class, $starting_clusters, $starting_cluster_dir, $dest_dir, $tmp_dir ) = $check->( @ARG );
	$tmp_dir //= $dest_dir;

	return run_and_time_filemaking_cmd(
		'mafft alignment',
		$dest_dir->child( alignment_filename_of_starting_clusters( $starting_clusters ) ),
		sub {
			my $aln_atomic_file = shift;
			my $tmp_aln_file    = path( $aln_atomic_file->filename );

			my $id_of_clusters = id_of_starting_clusters( $starting_clusters );

			my $local_exe_dir   = path( '/dev/shm' );
			my $local_mafft_exe = $local_exe_dir->child( path( $mafft_exe )->basename() );
			if ( ( -s $mafft_exe ) != ( -s $local_exe_dir ) ) {
				copy( $mafft_exe, $local_mafft_exe )
					or confess "Unable to copy MAFFT executable $mafft_exe to local executable $local_mafft_exe : $OS_ERROR";
			}
			if ( ! -x $local_mafft_exe->stat() ) {
				$local_mafft_exe->chmod( 'a+x' )
					or confess "Unable to chmod local MAFFT executable \"$local_mafft_exe\" : $OS_ERROR";
			}

			my $raw_seqs_filename  = Path::Tiny->tempfile( TEMPLATE => '.temp_raw_seqs.XXXXXXXXXXX',
			                                               DIR      => $tmp_dir,
			                                               SUFFIX   => '.fa',
			                                               CLEANUP  => 1,
			                                               );
			my $build_raw_seqs_result = __PACKAGE__->build_raw_seqs_file(
				$starting_clusters,
				$starting_cluster_dir,
				$raw_seqs_filename,
			);
			my $num_sequences = $build_raw_seqs_result->{ num_sequences };

			my @mafft_params_slow_high_qual = ( qw/ --amino --anysymbol --localpair --maxiterate 1000 --quiet / );
			my @mafft_params_fast_low_qual  = ( qw/ --amino --anysymbol --parttree  --retree     1    --quiet / );

			if ( $num_sequences  > 1 ) {
				my $mafft_params = ( $num_sequences <= 200 ) ? [ @mafft_params_slow_high_qual, "$raw_seqs_filename" ]
				                                             : [ @mafft_params_fast_low_qual,  "$raw_seqs_filename" ];

				INFO 'About to mafft-align    ' . $num_sequences . ' sequences for ' . $id_of_clusters;

				# TODO: Sort this out
				# rsync -av tools/mafft-6.864-without-extensions/binaries/ /dev/shm/mafft_binaries_dir/
				$ENV{  MAFFT_BINARIES } = '/dev/shm/mafft_binaries_dir';

				my ( $mafft_stdout, $mafft_stderr, $mafft_exit ) = capture {
					system( "$local_mafft_exe", @$mafft_params );
				};

				if ( ( $mafft_exit != 0 ) || ( defined( $mafft_stderr ) && $mafft_stderr ne '' ) ) {
					confess
						"mafft command "
						.join( ' ', ( "$local_mafft_exe", @$mafft_params ) )
						." failed with:\nstderr:\n$mafft_stderr\nstdout:\n$mafft_stdout";
				}

				INFO 'Finished mafft-aligning ' . $num_sequences . ' sequences for ' . $id_of_clusters;

				$tmp_aln_file->spew( $mafft_stdout );
			}
			else {
				INFO 'Copying single sequence for ' . $id_of_clusters;
				copy( $raw_seqs_filename, $tmp_aln_file )
					or confess "Unable to copy single sequence file $raw_seqs_filename to $tmp_aln_file : $OS_ERROR";
			}

			return { num_sequences => $num_sequences };
		}
	);

}

1;
