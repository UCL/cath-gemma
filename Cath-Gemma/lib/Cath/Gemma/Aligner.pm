package Cath::Gemma::Merge;

use strict;
use warnings;

# # Core
# use Digest::MD5 qw/ md5_hex /;
use FindBin;

# # Moo
# use Moo;
# use strictures 1;

# # Non-core (local)
use Path::Tiny;
use Types::Path::Tiny qw/ Path /;
# use Types::Standard qw/ Num Str /; 

# # Cath
# use Cath::Gemma::Types qw/ CathGemmaMerge /; 
# use Cath::Gemma::Util;

my $mafft_exe = "$FindBin::Bin/.././tools/mafft-6.864-without-extensions/core/mafft";

=head2 confess_if_defined

=cut

sub confess_if_defined {
	my $var = shift;
	if ( defined( $var ) ) {
		confess $var;
	}
}

=head2 make_compass_profile

=cut

sub make_compass_profile {
	my $starting_clusters    = shift;
	my $starting_cluster_dir = shift;
	my $dest_dir             = shift;

	my $id = id_of_starting_clusters( $starting_clusters );

	# Validate parameters
	confess_if_defined(
		   ArrayRef[Str]->validate( $starting_clusters    )
		// Path         ->validate( $starting_cluster_dir )
		// Path         ->validate( $dest_dir             )
	)

	my $temporary_dir     = dir( '', 'dev', 'shm' );
	my $exe_dir           = dir( '', 'dev', 'shm' );

	if ( -s $dest_file ) {
		return;
	}
	if ( -e $dest_file ) {
		$dest_file->remove()
			or confess "Cannot delete empty file $dest_file";
	}

	my $num_sequences        = get_num_sequences( $source_file );
	my $temporary_align_file = $temporary_dir->file( $dest_file->basename() . '.temporary_alignment_file.' . $PROCESS_ID );
	my @mafft_params_slow_high_qual = ( qw/ --amino --anysymbol --localpair --maxiterate 1000 --quiet / );
	my @mafft_params_fast_low_qual  = ( qw/ --amino --anysymbol --parttree  --retree     1    --quiet / );

	if ( $num_sequences  > 1 ) {
		my $mafft_params = ( $num_sequences <= 200 ) ? \@mafft_params_slow_high_qual
		                                             : \@mafft_params_fast_low_qual;
		# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		# !!!! THIS IS THE HIGH-QUALITY VERSION FOR S90S WITH 1 < N <= 200 SEQUENCES !!!!
		# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		my @mafft_command = ( 
			$mafft_exe,
			@$mafft_params,
			$source_file
		);

		warn localtime(time()) . " : About to align sequences with mafft\n";

		my ( $mafft_stdout, $mafft_stderr );
		run3( \@mafft_command, \undef, \$mafft_stdout, \$mafft_stderr );
		if ( defined( $mafft_stderr ) && $mafft_stderr ne '' ) {
			confess "Argh mafft command ". join( ' ', @mafft_command ) ." failed with:\n\n$mafft_stderr\n\n$mafft_stdout";
		}

		warn localtime(time()) . " : Finished aligning sequences with mafft\n";

		$temporary_align_file->spew( $mafft_stdout );
	}
	else {
		symlink $source_file, $temporary_align_file
			or confess "Arghh can't symlink $source_file, $temporary_align_file : $OS_ERROR";
	}

	
	my $temporary_small_aln_file  = $temporary_dir->file( 'small_temp_aln_file.' . $PROCESS_ID . '.faa' );
	my $temporary_small_prof_file = $temporary_dir->file( 'small_temp_aln_file.' . $PROCESS_ID . '.prof' );
	$temporary_small_aln_file->spew( "'>A\nA\n" );

	# TODO: Make this write to a temporary file and then rename to dest when finished

	my @compass_command = (
		$compass_build_exe,
		'-g',  '0.50001',
		'-i',  $temporary_align_file,
		'-j',  $temporary_small_aln_file,
		'-p1', $dest_file,
		'-p2', $temporary_small_prof_file,
	);

	warn localtime(time()) . " : About to build COMPASS profile\n";

	my ( $compass_stdout, $compass_stderr );
	run3( \@compass_command, \undef, \$compass_stdout, \$compass_stderr );
	# if ( defined( $compass_stderr ) && $compass_stderr ne '' ) {
	# 	confess "Argh compass failed with $compass_stderr";
	# }

	$temporary_align_file->remove()
		or confess "Cannot remove temporary_align_file $temporary_align_file : $OS_ERROR";
	$temporary_small_prof_file->remove()
		or confess "Cannot remove temporary_small_prof_file $temporary_small_prof_file : $OS_ERROR";


	# confess Dumper( [ \@mafft_command, $compass_stdout, $compass_stderr ] );

	# $working_dest_file;

	# $temporary_align_file;
}


1;