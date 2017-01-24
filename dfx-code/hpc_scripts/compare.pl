#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

use strict;

if (@ARGV < 7) 
	{ print "please provide: job_num, input_dir, profile_dir, output_dir, cutoff, executable, parameters\n"; exit; }

my ($job_num, $input_dir, $profile_dir, $output_dir, $evalue_cutoff, $executable, $parameters) = @ARGV;

my ($FH, $TMP, @compass_output, @pairs, $inf1, $inf2, $file, $c1, $c2, $evalue, @cols, $s, $exit_code);

my $lowest_evalue = 1000;

# pair only
my $pair_template = "%6d\t%6d";
my $pair_unpack_template = "A6A1A6";

# pair and E-value
my $score_template = $pair_template . "\t%03.2e";

$input_dir .= "/"; $profile_dir .= "/"; $output_dir .= "/";

#DEBUG see below!
#my $errors_file = $output_dir . "errors\.$job_num";

my $pairs_file = $input_dir . "job\.$job_num";

my $tmp_file = $input_dir . "temp\.$job_num";

my $result_file = $output_dir . "results\.$job_num";

my $done_file = $output_dir . "done\.$job_num";

# slurp pairs file
open ($FH, "<$pairs_file") || die "cannot open $pairs_file ($!)"; @pairs = <$FH>; close $FH;

open ($FH, ">$result_file") || die "cannot create $result_file ($!)";

my ($total, $better_than_cutoff) = (0, 0);

foreach (@pairs)

	{

	($c1, $s, $c2) = unpack($pair_unpack_template, $_);

	$c1 = int($c1); $c2 = int($c2);

	$inf1 = $profile_dir . $c1 . "\.prof";

	$inf2 = $profile_dir . $c2 . "\.prof";
	
	#DEBUG: print $c1, $c2, $inf1, $inf2;

	$evalue = $lowest_evalue;

	#DEBUG: print "$executable -i $inf1 -j $inf2 > $tmp_file 2>&1\n";

	#DEBUG there is no point in writing to an errors file since COMPASS writes normal messages to stderr by default!
	$exit_code = system("$executable $parameters -i $inf1 -j $inf2 > $tmp_file 2>\&1"); #>>$errors_file");

	if (($exit_code != 0) || (!-e $tmp_file) || (-z $tmp_file))

                {

                if ($exit_code == 0) 
			# empty output file
			{ $exit_code = 99999; } 
		else 
			# get system exit code
			{ $exit_code = $exit_code >> 8; }

                $file = $output_dir . $c1 . "\.prof\.stderr";

                open $TMP, ">$file"; print $TMP "$exit_code\n"; close $TMP;

		$file = $output_dir . $c2 . "\.prof\.stderr";

                open $TMP, ">$file"; print $TMP "$exit_code\n"; close $TMP;

		next;

                }

	open($TMP, "<$tmp_file"); @compass_output = <$TMP>; close $TMP;

	foreach(@compass_output)
			
		{
			
		#DEBUG: could match less for speed
		if (/^Smith-Waterman/)
				
			{
			
			chomp; @cols = split /\s+/; $evalue = $cols[6]; last;

			}
		}
	
	# if COMPASS fails this field contains the word 'not' and not the E-value (check newer versions for changes!)
	if ($evalue eq "not") { $evalue = 1000; }

	if ($evalue < $lowest_evalue) { $lowest_evalue = $evalue; }

	$total++;

	if ($evalue <= $evalue_cutoff) { $better_than_cutoff++; }

	# fixed length formatting for faster parsing with substr, this takes care of whitespace and newlines too!
	$s = sprintf "$score_template\n", $c1, $c2, $evalue;

	print $FH $s;

	}

close $FH;

# finished if no single evalue is lower than the cutoff anymore
open ($FH, ">$done_file") || die "cannot create $done_file ($!)";
print $FH "$total\t$better_than_cutoff\n";
close $FH;

unlink $tmp_file;

