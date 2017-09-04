package Cath::Gemma::Tool::Aligner;

use strict;
use warnings;

# Core
use Carp                qw/ confess                  /;
use English             qw/ -no_match_vars           /;
use File::Copy          qw/ copy move                /;
use FindBin;
use List::Util          qw/ sum0                     /;
use Time::HiRes         qw/ gettimeofday tv_interval /;
use v5.10;

# Non-core (local)
use Bio::AlignIO;
use Capture::Tiny       qw/ capture                  /;
use File::AtomicWrite;
use Log::Log4perl::Tiny qw/ :easy                    /;
use Path::Tiny;
use Type::Params        qw/ compile                  /;
use Types::Path::Tiny   qw/ Path                     /;
use Types::Standard     qw/ ArrayRef ClassName Str   /;

# Cath
use Cath::Gemma::Types  qw/
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 build_raw_seqs_file

TODOCUMENT

=cut

sub build_raw_seqs_file {
	shift;
	my $starting_clusters    = shift;
	my $starting_cluster_dir = shift;
	my $dest_file            = shift;

	my $dest_fh = $dest_file->openw();

	my $num_sequences = 0;

	my @seq_lengths;
	foreach my $starting_cluster ( @$starting_clusters ) {
		my $starting_cluster_file = $starting_cluster_dir->child( $starting_cluster . alignment_profile_suffix() );
		if ( ! -s $starting_cluster_file ) {
			confess "Cannot find non-empty starting cluster file \"$starting_cluster_file\"";
		}

		my $starting_cluster_data = $starting_cluster_file->slurp();
		my @starting_cluster_lines = split( /\n/, $starting_cluster_data );
		my $seq_length = 0;
		foreach my $starting_cluster_line ( @starting_cluster_lines ) {
			if ( $starting_cluster_line =~ /^>/ ) {
				++$num_sequences;
				if ( $seq_length != 0 ) {
					push @seq_lengths, $seq_length;
					$seq_length = 0;
				}
			}
			else {
				$seq_length += length( $starting_cluster_line );
			}
			print $dest_fh "$starting_cluster_line\n";
		}
		push @seq_lengths, $seq_length;
	}

	return {
		mean_seq_length => ( sum0( @seq_lengths ) / scalar( @seq_lengths ) ),
		num_sequences => $num_sequences
	};
}

=head2 make_alignment_file

TODOCUMENT

=cut

sub make_alignment_file {
	state $check = compile( ClassName, CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskProfileDirSet );
	my ( $class, $exes, $starting_clusters, $profile_dir_set ) = $check->( @ARG );

	return run_and_time_filemaking_cmd(
		'mafft alignment',
		$profile_dir_set->alignment_filename_of_starting_clusters( $starting_clusters ),
		sub {
			my $aln_atomic_file = shift;
			my $tmp_aln_file    = path( $aln_atomic_file->filename );

			my $id_of_clusters = id_of_starting_clusters( $starting_clusters );

			my $raw_seqs_filename  = Path::Tiny->tempfile( TEMPLATE => '.temp_raw_seqs.XXXXXXXXXXX',
			                                               DIR      => $exes->tmp_dir(),
			                                               SUFFIX   => '.fa',
			                                               CLEANUP  => 1,
			                                               );
			my $build_raw_seqs_result = __PACKAGE__->build_raw_seqs_file(
				$starting_clusters,
				$profile_dir_set->starting_cluster_dir(),
				$raw_seqs_filename,
			);
			my $num_sequences = $build_raw_seqs_result->{ num_sequences };

			my @mafft_params_slow_high_qual = ( qw/ --amino --anysymbol --localpair --maxiterate 1000 --quiet / );
			my @mafft_params_fast_low_qual  = ( qw/ --amino --anysymbol --parttree  --retree     1    --quiet / );

			if ( $num_sequences  > 1 ) {
				my $mafft_params = ( $num_sequences <= 200 ) ? [ @mafft_params_slow_high_qual, "$raw_seqs_filename" ]
				                                             : [ @mafft_params_fast_low_qual,  "$raw_seqs_filename" ];

				my $mafft_exe = $exes->mafft();

				INFO 'About to mafft-align    ' . $num_sequences . ' sequences for cluster ' . $id_of_clusters;

				my ( $mafft_stdout, $mafft_stderr, $mafft_exit ) = capture {
					system( "$mafft_exe", @$mafft_params );
				};

				if ( ( $mafft_exit != 0 ) || ( defined( $mafft_stderr ) && $mafft_stderr ne '' ) ) {
					confess
						"mafft command "
						.join( ' ', ( "$mafft_exe", @$mafft_params ) )
						." failed with:\nstderr:\n$mafft_stderr\nstdout:\n$mafft_stdout";
				}

				INFO 'Finished mafft-aligning ' . $num_sequences . ' sequences for cluster ' . $id_of_clusters;

				# Use Bio::AlignIO to rewrite the alignment to remove wrapping
				# because wrapped alignments occasionally cause problems in COMPASS 2.45
				my $flatten_filename  = Path::Tiny->tempfile( TEMPLATE => '.faa_flatten.XXXXXXXXXXX',
				                                              DIR      => $exes->tmp_dir(),
				                                              SUFFIX   => '.fa',
				                                              CLEANUP  => 1,
				                                              );
				$flatten_filename->spew( $mafft_stdout );
				my $fasta_in  = Bio::AlignIO->new(
					'-file'   => "$flatten_filename",
					'-format' => 'fasta',
				);
				my $fasta_out = Bio::AlignIO->new(
					'-file'   => ">$tmp_aln_file",
					'-flush'  => 0,
					'-format' => 'fasta',
					'-width'  => 32000,
				);

				while ( my $aln = $fasta_in->next_aln() ) {
					$fasta_out->write_aln( $aln );
				}
			}
			else {
				INFO 'Copying single sequence for cluster ' . $id_of_clusters;
				copy( $raw_seqs_filename, $tmp_aln_file )
					or confess "Unable to copy single sequence file $raw_seqs_filename to $tmp_aln_file : $OS_ERROR";
			}

			return {
				mean_seq_length => $build_raw_seqs_result->{ mean_seq_length },
				num_sequences   => $num_sequences,
			};
		}
	);

}

1;
