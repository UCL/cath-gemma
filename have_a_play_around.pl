#!/usr/bin/env perl

use strict;
use warnings;

use Carp                       qw/ confess                              /;
use Data::Dumper;
use English                    qw/ -no_match_vars                       /;
use feature                    qw/ say                                  /;
use Path::Class                qw/ dir file                             /;
use POSIX;

# use Getopt::Long;
use IPC::Run3;
# use List::Util                 qw/ max maxstr min minstr                /;
# use Moose;
# use MooseX::Params::Validate;
# use MooseX::Types::Path::Class qw/ Dir File                             /;
# use Params::Util               qw/_INSTANCE _ARRAY _ARRAY0 _HASH _HASH0 /;

# say "Hello world";

# my $example_sf = '1.20.58.70'   ; # Has 100 starting clusters, so 4950 all-vs-all
my $example_sf = '1.10.150.120' ; # Has  45 starting clusters, so  990 all-vs-all

use Digest::SHA1 qw/ sha1_hex /;


my $cluster_seqfile_suffix = '.faa';
my $result_tree_suffix     = '.trace';
my $compass_profile_suffix = '.prof';

# cp /export/people/ucbctnl/gemma_stuff/dfx/dfx_pfam1/tools/compass/compass_wp_245_fixed              /dev/shm/
# cp /export/people/ucbctnl/gemma_stuff/dfx/dfx_pfam1/tools/compass/compass_db1Xdb2_241               /dev/shm/
# cp /export/people/ucbctnl/gemma_stuff/dfx/dfx_pfam1/tools/mafft-6.864-without-extensions/core/mafft /dev/shm/
# rsync -av /export/people/ucbctnl/gemma_stuff/dfx/dfx_pfam1/tools/mafft-6.864-without-extensions/binaries/ /dev/shm/mafft_binaries_dir/
# setenv MAFFT_BINARIES /dev/shm/mafft_binaries_dir

$ENV{  MAFFT_BINARIES } = '/dev/shm/mafft_binaries_dir';

process_superfamily( $example_sf );

# 43,699
# 15,157

sub process_superfamily {
	my $sf_id = shift;

	my $input_root_dir         = dir ( '', 'export', 'people', 'ucbctnl', 'gemma_stuff', 'dfx_funfam2013_data__projects__gene3d_12' );
	my $start_seqfiles_rootdir = $input_root_dir->subdir( 'starting_clusters' );
	my $comp_result_tree_dir   = $input_root_dir->subdir( 'clustering_output' );

	my $working_area_root_dir  = dir( '', 'export', 'people', 'ucbctnl', 'gemma_stuff', 'dfx_funfam2013_data__projects__gene3d_12_working_area' );
	my $profiles_subdir        = 'compass_profiles';

	my $comp_result_tree_file = $comp_result_tree_dir  ->file  ( $sf_id . $result_tree_suffix );
	my $starting_cluster_dir  = $start_seqfiles_rootdir->subdir( $sf_id                       );

	my $sf_working_area = $working_area_root_dir->subdir( $sf_id );
	my $sf_profiles_dir = $sf_working_area->subdir( $profiles_subdir );
	if ( ! -d $sf_profiles_dir ) {
		$sf_profiles_dir->mkpath()
			or confess "Cannot make directory $sf_profiles_dir";
	}

	my @starting_cluster_nums;
	while ( my $starting_cluster_seqfile = $starting_cluster_dir->next ) {
		next unless -f $starting_cluster_seqfile;

		my $starting_cluster_seqbase = $starting_cluster_seqfile->basename();
		if ( $starting_cluster_seqbase !~ /^(\d+)$cluster_seqfile_suffix/ ) {
			warn "Skipping $starting_cluster_seqbase";
			next;
		}
		my $seq_num = $1;
		push @starting_cluster_nums, $seq_num;
	}
	@starting_cluster_nums = sort { $a <=> $b } @starting_cluster_nums;

	warn localtime(time()) . " : About to prepare starting cluster profiles...\n";
	foreach my $starting_cluster_num (@starting_cluster_nums) {
		make_compass_profile (
			$starting_cluster_dir->file( $starting_cluster_num . $cluster_seqfile_suffix ),
			$sf_profiles_dir     ->file( $starting_cluster_num . $compass_profile_suffix )
		);
	}

	warn localtime(time()) . " : About to do initial all-vs-all...\n";
	my $results = compass_all_vs_all( \@starting_cluster_nums, $sf_profiles_dir, $compass_profile_suffix );

	my $new_seqfiles_dir = $sf_working_area->subdir( 'new_cluster_seqfiles' );
	if ( ! -d $new_seqfiles_dir ) {
		$new_seqfiles_dir->mkpath()
			or confess "Cannot make new_seqfiles_dir $new_seqfiles_dir : $OS_ERROR";
	}

	build_tree(
		\@starting_cluster_nums,
		$results,
		$new_seqfiles_dir,
		$sf_profiles_dir,
		$starting_cluster_dir
	);
}

# sub log10 {
# 	my $n = shift;
# 	return log( $n ) / log( 10 );
# }

sub build_tree {
	my $starting_cluster_nums  = shift;
	my $results                = shift;
	my $new_seqfiles_dir       = shift;
	my $compass_profiles_dir   = shift;
	my $start_seqfiles_dir     = shift;

	# my %cluster_id_of_index;
	my %index_of_cluster_id;
	my @clusters;
	my $index_ctr = 0;
	foreach my $cluster_id ( @$starting_cluster_nums ) {
		# $cluster_id_of_index{ $index_ctr  } = $cluster_id;
		$index_of_cluster_id{ $cluster_id } = $index_ctr;
		push @clusters, [ $cluster_id ];
		++$index_ctr;
	}
	my $new_cluster_ctr = $starting_cluster_nums->[ -1 ] + 1;
	# warn Dumper( [ \%index_of_cluster_id, \@clusters, $new_cluster_ctr ] );

	@$results = sort { $a->[ 2 ] <=> $b->[ 2 ] } @$results;

	my $best_evalue   = $results->[ 0 ]->[ 2 ];
	my $evalue_cutoff = ( 10 ** ( ceil( log10( $best_evalue ) / 10 ) * 10 ) );

	my @actions;
	my $new_results = [];
	while ( scalar( @$results ) > 0 ) {
		process_to_evalue_cutoff(
			$evalue_cutoff,
			$new_results,
			\$new_cluster_ctr,
			$results,
			\@actions,
			\@clusters,
			\%index_of_cluster_id,
			$new_seqfiles_dir,
			$compass_profiles_dir,
			$start_seqfiles_dir
		);

		if ( scalar( @$new_results ) > 0 ) {
			integrate_new_results( $results, $new_results );
		}
		else {
			$evalue_cutoff *= 1e10;
		}

		# foreach my $action ( @actions ) {
		# 	print join( ' ', @$action )."\n";
		# }
		# print "\n$evalue_cutoff\n\n";
		# if ( scalar( @$results ) ) {
		# 	print Dumper( $results->[ 0 ] );
		# }
	}

	foreach my $action ( @actions ) {
		my @num_strs = map { sprintf( '%-8d', $ARG ) } @$action[ 0 .. 2 ];
		print join( '', @num_strs ) . $action->[ 3 ] . "\n";

	}
}


sub integrate_new_results {
	my $results     = shift;
	my $new_results = shift;

	foreach my $new_result_set ( @$new_results ) {
		push @$results, @$new_result_set;
	}

	@$results = sort { $a->[ 2 ] <=> $b->[ 2 ] } @$results;
	@$new_results = ();

	return $results;
}

sub process_to_evalue_cutoff {
	my $evalue_cutoff        = shift;
	my $new_results          = shift;
	my $new_cluster_ctr_ref  = shift;
	my $results              = shift;
	my $actions              = shift;
	my $clusters             = shift;
	my $index_of_cluster_id  = shift;
	my $new_seqfiles_dir     = shift;
	my $compass_profiles_dir = shift;
	my $start_seqfiles_dir   = shift;

	if ( scalar( @$new_results ) > 0 ) {
		confess "Oh dear oh dear oh dear";
	}

	while ( scalar( @$results ) > 0 && $results->[ 0 ]->[ 2 ] <= $evalue_cutoff ) {
	# foreach my $result ( @$results ) {
		my $result = shift @$results;
		my ( $id1, $id2, $evalue ) = @$result;

		if ( exists( $index_of_cluster_id->{ $id1 } ) && exists( $index_of_cluster_id->{ $id2 } ) ) {
			push @$actions, [ $id1, $id2, $$new_cluster_ctr_ref, $evalue ];
			my $index1 = $index_of_cluster_id->{ $id1 };
			my $index2 = $index_of_cluster_id->{ $id2 };

			my $cluster1 = $clusters->[ $index1 ];
			my $cluster2 = $clusters->[ $index2 ];

			my @combined_cluster_ids = ( @{ $clusters->[ $index1 ] }, @{ $clusters->[ $index2 ] } );
			$clusters->[ $index1 ] = \@combined_cluster_ids;
			$clusters->[ $index2 ] = undef;
			delete $index_of_cluster_id->{ $id1 };
			delete $index_of_cluster_id->{ $id2 };
			$index_of_cluster_id->{ $$new_cluster_ctr_ref } = $index1;

			build_new_profile(
				$$new_cluster_ctr_ref,
				\@combined_cluster_ids,
				$new_seqfiles_dir,
				$compass_profiles_dir,
				$start_seqfiles_dir
			);

			# foreach my $id ( sort( { $a <=> $b } keys( %index_of_cluster_id ) ) ) {
			# 	warn $id . '.' . sha1_hex( @{ $clusters->[ $index_of_cluster_id->{ $id } ] } );
			# }

			my @current_cluster_ids = map {
				my $id = $ARG;
				my @starting_clusters_in_cluster = @{ $clusters->[ $index_of_cluster_id->{ $id } ] };
				if ( scalar( @starting_clusters_in_cluster ) > 1 ) {
					$id . '.' . sha1_hex( @starting_clusters_in_cluster );
				}
				else {
					$id;
				}
			} ( sort( { $a <=> $b } keys( %$index_of_cluster_id ) ) );

			my $results = compass_single(
				$compass_profiles_dir,
				$$new_cluster_ctr_ref . '.' . sha1_hex( @combined_cluster_ids ),
				\@current_cluster_ids
			);
			push @$new_results, $results;

			# warn Dumper( [
			# 	$result,
			# 	$actions,
			# 	$clusters,
			# 	$index_of_cluster_id,
			# 	\@current_cluster_ids,
			# ] )."\n";

			# if ( $$new_cluster_ctr_ref == 2996 ) {
			# 	confess Dumper( $results );
			# }

			++$$new_cluster_ctr_ref;
		}
	}
}

sub compass_single {
	my $compass_profiles_dir = shift;
	my $new_id               = shift;
	my $old_ids              = shift;

	my $new_file      = $compass_profiles_dir->file( $new_id . $compass_profile_suffix );

	my $temporary_dir = dir( '', 'dev', 'shm' );
	my $temp_db_file  = $temporary_dir->file( 'temp_db.' . $new_id . '.' . $PROCESS_ID );
	my $temp_db_fh    = $temp_db_file->openw();

	foreach my $old_id ( @$old_ids ) {
		my $old_file = $compass_profiles_dir->file( $old_id . $compass_profile_suffix );
		print $temp_db_fh $old_file->slurp();
	}
	$temp_db_fh->close()
		or confess "";

	warn localtime(time()) . " : About to run single COMPASS scan\n";
	my $results = run_compass( $temp_db_file, $new_file );

	$temp_db_file->remove()
		or confess "Cannot remove temp_db_file $temp_db_file : $OS_ERROR";

	return $results;
}

sub build_new_profile {
	my $new_cluster_id         = shift;
	my $starting_cluster_ids   = shift;
	my $new_seqfiles_dir       = shift;
	my $compass_profiles_dir   = shift;
	my $start_seqfiles_dir     = shift;

	my $sha1       = sha1_hex( @$starting_cluster_ids );
	my $files_base = $new_cluster_id . '.' . $sha1;

	my $raw_seq_file      = $new_seqfiles_dir    ->file( $files_base . $cluster_seqfile_suffix );
	my $compass_prof_file = $compass_profiles_dir->file( $files_base . $compass_profile_suffix );

	if ( ! -s $raw_seq_file ) {
		if ( -e $raw_seq_file ) {
			$raw_seq_file->remove()
				or confess "Cannot remove raw_seq_file $raw_seq_file : $OS_ERROR";
		}
		if ( -e $compass_prof_file ) {
			$compass_prof_file->remove()
				or confess "Cannot remove compass_prof_file $compass_prof_file : $OS_ERROR"
		}

		my $raw_seq_fh = $raw_seq_file->openw();
		foreach my $starting_cluster_id ( @$starting_cluster_ids ) {
			my $cluster_file = $start_seqfiles_dir->file( $starting_cluster_id . $cluster_seqfile_suffix );
			print $raw_seq_fh $cluster_file->slurp();
		}
		$raw_seq_fh->close()
			|| confess "";
	}

	make_compass_profile(
		$raw_seq_file,
		$compass_prof_file
	);
}

sub compass_all_vs_all {
	my $cluster_nums           = shift;
	my $sf_profiles_dir        = shift;
	my $compass_profile_suffix = shift;

	my $temporary_dir    = dir( '', 'dev', 'shm' );
	my $temp_db_file     = $temporary_dir->file( 'temp_db.' . $PROCESS_ID );
	my $temp_db_fh = $temp_db_file->openw();

	warn localtime(time()) . " : About to write all-vs-all db file...\n";
	foreach my $cluster_num ( @$cluster_nums ) {
		my $cluster_file = $sf_profiles_dir->file( $cluster_num . $compass_profile_suffix );
		print $temp_db_fh $cluster_file->slurp();
	}
	$temp_db_fh->close()
		|| confess "";
	warn localtime(time()) . " : About to run all-vs-all compass.\n";

	my $results = run_compass( $temp_db_file, $temp_db_file );

	$temp_db_file->remove()
		|| confess "Unable to remove temporary database file \"$temp_db_file\" : $OS_ERROR";

	return $results;
}

sub run_compass {
	my $file_a = shift;
	my $file_b = shift;

	my $file_a_basename = $file_a->basename();

	my $exe_dir          = dir( '', 'dev', 'shm' );
	my $compass_scan_exe = $exe_dir->file( 'compass_db1Xdb2_241' );

	my @compass_scan_command = (
		$compass_scan_exe,
		'-g', '0.50001',
		'-i', $file_a,
		'-j', $file_b,
		'-n', '0',
	);

	# if ( $file_a ne $file_b) {
	# 	confess join( ' ', @compass_scan_command );
	# }

	my ( @outputs, $last_id1, $last_id2, $compass_scan_stderr );
	run3(
		\@compass_scan_command,
		\undef,
		sub {
			my $line = shift;
			if ( $line =~ /^Ali1:\s+(\S+)\s+Ali2:\s+(\S+)/ ) {
				if ( defined( $last_id1 ) || defined( $last_id2 ) ) {
					confess "Argh:\n\"$line\"\n$last_id1\n$last_id2\n";
				}
				$last_id1 = $1;
				$last_id2 = $2;
				foreach my $last_id ( \$last_id1, \$last_id2 ) {
					if ( $$last_id =~ /\/(\d+)(\.\w+)?\.prof\.temporary_alignment_file/ ) {
						$$last_id = $1;
					}
					# elsif ( $$last_id =~ /$file_a_basename/ && defined( $id ) ) {
					# 	$$last_id = $id;
					# }
					else {
						confess "Argh $$last_id";
					}
				}
			}
			if ( $line =~ /\bEvalue (.*)$/ ) {
				if ( $1 ne '** not found **' ) {
					if ( $line =~ /\bEvalue = (\S+)$/ ) {
						push @outputs, [ $last_id1, $last_id2, $1 ];
					}
					else {
						confess "Argh";
					}
				}
				if ( ! defined( $last_id1 ) || ! defined( $last_id2 ) ) {
					confess "Argh";
				}
				$last_id1 = undef;
				$last_id2 = undef;
			}
		},
		\$compass_scan_stderr
	);

	return \@outputs;
}


sub get_num_sequences {
	my $file = shift;

	my $count = 0;
	my @lines = $file->slurp();
	foreach my $line ( @lines ) {
		if ( $line =~ /^>/ ) {
			++$count;
		}
	}
	return $count;
}

sub make_compass_profile {
	my $source_file = shift;
	my $dest_file   = shift;

	my $temporary_dir     = dir( '', 'dev', 'shm' );
	my $exe_dir           = dir( '', 'dev', 'shm' );
	my $mafft_exe         = $exe_dir->file( 'mafft'                );
	my $compass_build_exe = $exe_dir->file( 'compass_wp_245_fixed' );

	# warn "$source_file $dest_file\n";

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