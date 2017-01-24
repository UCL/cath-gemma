#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

use strict;

use FindBin qw ($Bin); use lib "$Bin/../modules";
use common;
use hpcpart;


common::check_args(\@ARGV, 3, "project superfamily overwrite? [run_id]");
my ($project, $superfamily, $overwrite_mode) = @ARGV;
$overwrite_mode = ($overwrite_mode eq "yes");

my $run_id = common::check_opt_args(\@ARGV, 4, 0);

hpcpart::init_hpc_dirs_and_files($project, $superfamily);

if ( ! -d $starting_cluster_dir ) { print "WARNING: no starting clusters found!\n"; exit; }

my ($evalue_threshold, $errors);


#DEBUG
common::new_dir_if_nexists($clustering_output_data_dir);

#DEBUGxxx see comment at end of script below
my $clustering_mfasta_dir = "$superfamily_clustering_dir/mfasta";
#DEBUGxxx see comment in hpcpart.pm
my $fresh_clustering_trace_file = "$superfamily_clustering_dir/trace/merges.trace";


if ((! -d $superfamily_clustering_dir) || $overwrite_mode)
	{
	common::rm_dir_if_exists($superfamily_clustering_dir);
	#DEBUG use recursive copy Perl module instead
	#DEBUG create all other dirs here too (now in clustering script)
	common::new_or_clear_dir($superfamily_clustering_dir);
	common::safe_sys_call(SYSTEM_CALL_COPY . " -r $starting_cluster_dir $clustering_mfasta_dir",
                              "copying starting clusters");
	}
else
	{
	print "WARNING: $superfamily_clustering_dir exists, keeping existing data!\n"; exit;
	}
			
$errors = 0;

print "CLUSTERING SUPERFAMILY DATASET...\n";

foreach (@clustering_granularity_steps)
	
	{

	$evalue_threshold = $_;
	
	print "LEVEL $evalue_threshold\n";
	
	if (system("$scripts_dir/cluster_sequences.pl $superfamily_clustering_dir $evalue_threshold $comparisons_fraction_of_all_per_iteration $merges_max_per_iteration $run_id") != 0)
		{
		$errors = 1;
		last;
		}
		
	}

if ($errors)
	{
	print "ERRORs in clustering dataset $superfamily in iteration $evalue_threshold, clustering terminated!\n";
	}
#DEBUG usually the above errors occur when alignments get too big for COMPASS; we then artificially root the tree later on
#else
	{
	#DEBUG may wanna resolve $superfamily_clustering_trace_file location mismatch between local/HPC
	#DEBUG this is the storage (target) destination of this file once clustering has finished
	#DEBUG move the trace file to storage here
	#NOTE this overwrites by default
	common::safe_move($fresh_clustering_trace_file, $superfamily_clustering_trace_file);

	#DEBUG can delete family work dir here, it's only used during clustering
	}
