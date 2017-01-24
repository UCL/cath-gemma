#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

use strict;

use File::Copy qw(copy);

if (@ARGV < 8) 
	{ print "please provide: job_number, input_dir, faa_dir, output_dir, mafft_executable, mafft_hq_params, mafft_lq_params, mafft_aln_quality_seq_num_cutoff\n"; exit; }

my ($job_num, $input_dir, $faa_dir, $output_dir, $mafft_executable, 
	$mafft_hq_params, $mafft_lq_params, $mafft_aln_quality_seq_num_cutoff) = @ARGV;

#DEBUG make sure these 'x y z' (internal space) command line args are passed correctly
#print "$mafft_hq_params, $mafft_lq_params\n";

my ($FAAF, $TMP, $faa_file, $aln_file, $file, $seq_count, $exit_code);

$input_dir .= "/"; $faa_dir .= "/"; $output_dir .= "/";

my $errors_file = $output_dir . "errors\.$job_num";

my $faalist_file = $input_dir . "job\.$job_num";

my $done_file = $output_dir . "done\.$job_num";

#my $mafft_executable = $mafft_base_dir . "/core/mafft";

#DEBUG this setting is now inherited from the job submission script (which in turn inherits 
#DEBUG it from the calling perl script)
#$ENV{"MAFFT_BINARIES"} = "$mafft_base_dir/binaries";

my ($aligned, $total) = (0, 0);

open $FAAF, "<$faalist_file";

while (<$FAAF>)

	{

	chomp;

	$faa_file = $faa_dir . $_ . "\.faa";

	$seq_count = `grep -c ">" $faa_file`; chomp $seq_count;

	$aln_file = $output_dir . $_ . "\.aln";

	$aligned++; $total++;

	if ($seq_count == 1) 

		{ 

		copy($faa_file, $aln_file);
		#system("cp $faa_file $aln_file");

		next;

		}

	if ($seq_count <= $mafft_aln_quality_seq_num_cutoff)

        	{

		#print "$mafft_executable $mafft_hq_params --quiet $faa_file > $aln_file 2>>$errors_file\n";

	 	$exit_code = system("$mafft_executable $mafft_hq_params --quiet $faa_file > $aln_file 2>>$errors_file");
	
		}

	else

        	{

        	$exit_code = system("$mafft_executable $mafft_lq_params --quiet $faa_file > $aln_file 2>>$errors_file")

        	}

	#DEBUG: seems to exit with 0 even if aln error, e.g. illegal character J;
	#DEBUG  used to read -e and ! -z
	# if exit code is not 0 or the output file does not exist or has size 0
	if (($exit_code != 0) || (! -s $aln_file)) 

		{

		if ($exit_code == 0) 
			{ $exit_code = 99999; } 
		else 
			# get system exit code
			{ $exit_code = $exit_code >> 8; }

		$aligned--;

		$file = $output_dir . $_ . "\.faa\.stderr";

		open $TMP, ">$file"; print $TMP "$exit_code\n"; close $TMP;

		}

	}

close $FAAF;

# delete the errors file if it's empty
if (-z $errors_file) { unlink($errors_file); }

# if this file does not exist after this script has terminated (prematurely, e.g. in MAFFT above),
# the job script can detect this and report the job has failed
open $TMP, ">$done_file"; print $TMP "$aligned\t$total\n"; close $TMP;

