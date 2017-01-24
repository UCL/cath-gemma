#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

use strict;

if (@ARGV < 6) 
	{ print "please provide: job_number, input_dir, aln_dir, output_dir, executable, parameters\n"; exit; }

my ($job_num, $input_dir, $aln_dir, $output_dir, $executable, $parameters) = @ARGV;

my ($ALNF, $TMP, $aln_file, $profile_file, $file, $exit_code);

$input_dir .= "/"; $aln_dir .= "/"; $output_dir .= "/";

my $errors_file = $output_dir . "errors\.$job_num";

my $alnlist_file = $input_dir . "job\.$job_num";

my $tmp_file = $input_dir . "temp\.$job_num";

my $done_file = $output_dir . "done\.$job_num";

my ($total, $generated) = (0, 0);

open $ALNF, "<$alnlist_file";

while (<$ALNF>)

	{

	chomp;

	$aln_file = $aln_dir . $_ . "\.aln";

	$profile_file = $output_dir . $_ . "\.prof";

	$generated++; $total++;

	$exit_code = system("$executable $parameters -i $aln_file -j $aln_file -p1 $profile_file -p2 $tmp_file 1>/dev/null 2>>$errors_file");

	if (($exit_code != 0) || (!-e $profile_file) || (-z $profile_file)) 

		{

		if ($exit_code == 0) 
			# empty output file
			{ $exit_code = 99999; } 
		else 
			# get system exit code
			{ $exit_code = $exit_code >> 8; }
		       		       
		$generated--;

		$file = $output_dir . $_ . "\.aln\.stderr";

		open $TMP, ">$file"; print $TMP "$exit_code\n"; close $TMP;

		}

	}

close $ALNF;

unlink($tmp_file);

#DEBUG
if (-z $errors_file) { unlink($errors_file); }

#NEWFUNC
open $TMP, ">$done_file"; print $TMP "$generated\t$total\n"; close $TMP;

