package Cath::Gemma::Aligner;

use strict;
use warnings;

# # Core
use Capture::Tiny       qw/ capture                  /;
use Carp                qw/ confess                  /;
use English             qw/ -no_match_vars           /;
use Exporter            qw/ import                   /;
use File::Copy          qw/ copy move                /;
use FindBin;
use Log::Log4perl::Tiny qw/ :easy                    /;
use Time::HiRes         qw/ gettimeofday tv_interval /;
use v5.10;

our @EXPORT = qw/
	make_alignment_file
	/;

# # Non-core (local)
use Path::Tiny;
use Type::Params      qw/ compile                         /;
use Types::Path::Tiny qw/ Path                            /;
use Types::Standard   qw/ ArrayRef ClassName Optional Str /;

# # Cath
use Cath::Gemma::Util;

my $mafft_exe = "$FindBin::Bin/.././tools/mafft-6.864-without-extensions/core/mafft";

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
		my $starting_cluster_file = $starting_cluster_dir->child( $starting_cluster . '.faa' );
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

=cut

sub make_alignment_file {
	state $check = compile( ClassName, ArrayRef[Str], Path, Path, Optional[Path] );
	my ( $class, $starting_clusters, $starting_cluster_dir, $dest_dir, $tmp_dir ) = $check->( @ARG );

	$tmp_dir //= $dest_dir;

	if ( ! -d $dest_dir ) {
		$dest_dir->mkpath()
			or confess "Unable to make alignment output directory \"$dest_dir\" : $OS_ERROR";
	}

	my $id_of_clusters     = id_of_starting_clusters( $starting_clusters );
	my $alignment_basename = alignment_filename_of_starting_clusters( $starting_clusters );
	my $alignment_filename = $dest_dir->child( $alignment_basename );
	my $mafft_duration     = undef;
	if ( -s $alignment_filename ) {
		return {
			alignment_filename => $alignment_filename,
		};
	}
	if ( -e $alignment_filename ) {
		$alignment_filename->remove()
			or confess "Cannot delete empty file $alignment_filename";
	}

	my $local_exe_dir   = path( '/dev/shm' );
	my $local_mafft_exe = $local_exe_dir->child( path( $mafft_exe )->basename() );
	if ( ( -s $mafft_exe ) != ( -s $local_exe_dir ) ) {
		copy( $mafft_exe, $local_mafft_exe )
			or confess "Unable to copy MAFFT executable $mafft_exe to local executable $local_mafft_exe : $OS_ERROR";
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

	my $temporary_align_file = Path::Tiny->tempfile( TEMPLATE => '.tmp_aln.' . $id_of_clusters . '.XXXXXXXXXXX',
	                                                 DIR      => $dest_dir,
	                                                 SUFFIX   => '.faa',
	                                                 CLEANUP  => 1,
	                                                 );
	my @mafft_params_slow_high_qual = ( qw/ --amino --anysymbol --localpair --maxiterate 1000 --quiet / );
	my @mafft_params_fast_low_qual  = ( qw/ --amino --anysymbol --parttree  --retree     1    --quiet / );

	if ( $num_sequences  > 1 ) {
		my $mafft_params = ( $num_sequences <= 200 ) ? \@mafft_params_slow_high_qual
		                                             : \@mafft_params_fast_low_qual;

		INFO 'About to align ' . $num_sequences . ' sequences (' . $id_of_clusters . ') with mafft';

		# TODO: Sort this out
		# rsync -av tools/mafft-6.864-without-extensions/binaries/ /dev/shm/mafft_binaries_dir/
		$ENV{  MAFFT_BINARIES } = '/dev/shm/mafft_binaries_dir';

		my $mafft_t0 = [ gettimeofday() ];
		my ( $mafft_stdout, $mafft_stderr ) = capture {
		  system( "$local_mafft_exe", @$mafft_params, "$raw_seqs_filename" );
		};

		if ( defined( $mafft_stderr ) && $mafft_stderr ne '' ) {
			confess
				"mafft command "
				.join( ' ', ( "$local_mafft_exe", @$mafft_params, "$raw_seqs_filename" ) )
				." failed with:\nstderr:\n$mafft_stderr\nstdout:\n$mafft_stdout";
		}
		$mafft_duration = tv_interval ( $mafft_t0, [ gettimeofday() ] );

		INFO 'Finished aligning ' . $num_sequences . ' sequences (' . $id_of_clusters . ') in ' . $mafft_duration . 's with mafft';

		$temporary_align_file->spew( $mafft_stdout );
	}
	else {
		copy( $raw_seqs_filename, $temporary_align_file )
			or confess "Unable to copy single sequence file $raw_seqs_filename to $temporary_align_file : $OS_ERROR";
	}

	if ( ! -e $alignment_filename ) {
		move( $temporary_align_file, $alignment_filename );
	}

	return {
		alignment_filename => $alignment_filename,
		(
			defined( $mafft_duration )
			? ( mafft_duration => $mafft_duration )
			: ()
		),
		num_sequences      => $num_sequences
	};
}


1;