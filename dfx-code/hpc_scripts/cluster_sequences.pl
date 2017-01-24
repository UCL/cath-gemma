#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

=cut 

REQUIRES

# paths for the following are all set in the configuration file

MAFFT (for aligning sequences)
COMPASS (for comparing multiple sequence alignments)
*.job job submission scripts (used with qsub on the submitting node)
*.pl job node scripts (called on the respective node by the submission scripts)

TODO:

- maybe replace all the unpacks and sprintfs by splits and chomps again - now that split/chomp is 
  probably faster than unpack and substr (then also have to change job and node scripts back)
- put in more checks as e.g. if cmd line args are numeric, could use a cmd line module
- maybe replace POSIX find calls
- rewrite _local subroutines?

- can we use more common.pm things instead of defining / having them in here?
- could further develop generate_pairs_list_file_using_centers() as a better non-random way to select 
  pairs with pivot points 

ABBREVIATIONS: res man = resource manager; 

=cut

use strict;

use FindBin qw ($Bin); use lib "$Bin/../modules";
use common;
#use hpcpart;
use fasta;

use File::Path qw(mkpath rmtree);

#DEBUGxxx add more default values, e.g. paths to 3rd party tools, to allow for
#DEBUGxxx missing config file(s)?
my $comparisons_fraction_of_all_per_iteration = 1;
my $comparisons_min_per_iteration = 2000000;
my $comparisons_max_per_iteration = 10000000;

my $merges_max_per_iteration = 0xFFFFFF;
my $merges_max_recursions = 0;

#NOTE all child scripts are expected in the same directory as this one
my $scripts_dir = $Bin;

#DEBUGxxx
my ($base_work_dir, $eval_threshold) = (".", "100");

common::check_args(\@ARGV, 4, "base_work_dir E-value_threshold comparisons_%_per_iteration merges_max_per_iteration [run_id]");
($base_work_dir, $eval_threshold, $comparisons_fraction_of_all_per_iteration, $merges_max_per_iteration) = @ARGV;

my $run_id = common::check_opt_args(\@ARGV, 5, 0);

# conversions/formatting of input parameters

#DEBUG!!! overwrite default - in fact we can remove the max criterion entirely
if ($comparisons_fraction_of_all_per_iteration) 
	{ $comparisons_max_per_iteration = common::INFINITY; }

$comparisons_fraction_of_all_per_iteration /= 100;
$run_id = sprintf "%02d", $run_id;

#DEBUGxxx
$clustering_config_file = "$scripts_dir/" . common::CLUSTERING_CONFIG_FILE_NAME;
# called as an autonomous tool, i.e., working by itself
if (-e $clustering_config_file)
	{
	#DEBUGxxx see config file comment!
	$tools_dir = "$scripts_dir/tools";

	# a single file is assumed to contain _all_ settings required, unlike below
	common::load_settings($clustering_config_file, 1);

	#$hpc_user_name = ...
	}
# called by wrapper script, i.e., working as part of the DFX pipeline
else
	{
	#DEBUGxxx see config file comment!
	$tools_dir = "$scripts_dir/../tools";

	# the settings are spread over a range of config files
	$clustering_config_file = "$scripts_dir/../" . common::CLUSTERING_CONFIG_FILE_NAME;
	$thirdpartytools_config_file = "$scripts_dir/../" . common::THIRDPARTYTOOLS_CONFIG_FILE_NAME;
	$hpcjob_config_file = "$scripts_dir/../" . common::HPCJOB_CONFIG_FILE_NAME;

	# the generic config file (located automatically, provides $local_base_work_dir)
	common::load_settings(common::PIPELINE_CONFIG_FILE_NAME, 1); 
	# mainly needed in HPC part
	common::load_settings($clustering_config_file, 1); 
	# defining paths to third-party tools and parameter settings 
	common::load_settings($thirdpartytools_config_file, 1);
	# the only config file specific to the HPC part of the pipeline
	common::load_settings($hpcjob_config_file, 1); 
	}

#DEBUG!!! if $project = "", all dirs will be relative to the CWD, but we don't use them anyway
#hpcpart::init_hpc_dirs_and_files("", $base_work_dir); 
#use localpart;
#localpart::init_local_dirs_and_files("", $base_work_dir);

my (
	
	$temp_dir,
	
	$mfasta_dir,
	$alignments_dir,
	$profiles_dir,

	$jobs_dir,
	$results_dir,

	$trace_dir,
	
	$stdout_dir,
	$stderr_dir,	
	
	$old_mfasta_dir,
	$problem_mfasta_dir,

	$old_alignments_dir,
	$problem_alignments_dir,

	$old_profiles_dir,
	$problem_profiles_dir,

	$pairs_list_file,
	$mfasta_list_file,
	$profiles_list_file,

	$matrix_file,
	$matrix_dimensions_file,

	$results_file,
	$kept_results_file,
	$new_kept_results_file,
	$stored_results_file,
	$inactive_stored_results_file,

	$temp_file_generic,
	$temp_file_merge_sort,

	$log_file,
	$qstat_output_file);
	
init_dirs_and_files();

#DEBUG earlier?
if (! -d $mfasta_dir) { print "ERROR: put starting clusters into $mfasta_dir first!\n"; exit; }

my $align_job_script = "$scripts_dir/align.job";
my $profile_job_script = "$scripts_dir/profile.job";
my $compare_job_script = "$scripts_dir/compare.job";

my $align_script = "$scripts_dir/align.pl";
my $profile_script = "$scripts_dir/profile.pl";
my $compare_script = "$scripts_dir/compare.pl";

#DEBUG!!! vars for resource usage on submit node (sorting is the main memory hog), make this a cmd parameter too
# these are the upper limits for local memory used when sorting files on the submit node
my $sort_small_sort_mem = "100M";
# used for merge-sorts (of multiple results files)
my $sort_big_sort_mem = "1500M";


# --GLOBAL DUMMY VARIABLES------------------------------------------------

my ($i, $j, $k, $l, $c1, $c2, @cols, $tab, $ref);

#DEBUG initialise
my $iteration = 0; 

#DEBUG could move to wrapper script
common::new_or_clear_dir($stdout_dir); 
common::new_or_clear_dir($stderr_dir);
common::new_dir_if_nexists($temp_dir);

#DEBUG remove later; if turned on this can cause trouble! only for debugging
my $keep_all_job_stderr_files = 0;

# this is where we redirect qsub's output to
my $res_man_output_goes_to = "/dev/null"; #"&1";

# --DATA STORAGE TEMPLATES------------------------------------------------

# globally used sprintf/unpack templates for writing and reading lines (rows) of pair and results files
# a pair of cluster numbers only, for pairs files
my $pair_template = "%6d\t%6d";
my $pair_unpack_template = "A6A1A6";

# pair and E-value, for results files
my $score_template = $pair_template . "\t%03.2e";
my $score_unpack_template = $pair_unpack_template . "A1A9";

# --CONSTANTS ------------------------------------------------------------

use constant
{

	RES_MAN_CALL_QSTAT => "qstat",
	RES_MAN_CALL_QSUB => "qsub",
	RES_MAN_CALL_QDEL => "qdel"

};

# --COMPOUND CONSTANTS----------------------------------------------------

#DEBUG one could also do this via the qselect command of SGE/PBS
# when running for different families in parallel this identifies jobs belonging to each instance
my $job_prefix = "$qstat_job_name_prefix$run_id";

# qstat (when executed with default parameters) currently uses different output formats in SGE and PBS/Torque
if ($qstat_username_before_jobname) 
	{ $qstat_user_job_grep = "$hpc_user_name.* $job_prefix.*"; }	# PBS/Torque
else
	{ $qstat_user_job_grep = "$job_prefix.* $hpc_user_name.*"; }	# SGE (default)

# ...and get only the relevant (for this particular run) lines from all lines (jobs) of that user using this command
my $egrep_qs_cmd = SYSTEM_CALL_EGREP . " '$qstat_user_job_grep $qstat_pending_states ' $qstat_output_file";

my $job_no_length = 4;

# --VARIABLES-------------------------------------------------------------

# globally used lists 
my (@current_clusters, @new_clusters, @deleted_clusters, @pairs_matrix, @jobs);

# globally used file handles
my $LOG;

# globally used scalars
my ($pairs_matrix_offset, $cl_bit_hash, $num_jobs, $sub_jobs, 
	$current_cluster_count, $total_comps_left, $pair, $evalue, $num_seqs, 
	$seq_count, $flag, $biggest_cluster_seqs, $faa_file, $aln_file, $profile_file,
	$exit_code, $done_bit_hash, $submit_str);

# same here; dynamically calculated in each round
my ($compare_jobs, $compare_job_size, $align_job_size, $profile_job_size, 
	$pairs_this_iteration);

# this holds memory and runtime limits and is dynamically generated for each job submission
my $standard_resman_parameters;

# ------------------------------------------------------------------------
# --INIT------------------------------------------------------------------
# ------------------------------------------------------------------------

#DEBUG could capture current setting here and restore later (there might be redirection active already)
# this turns off caching of print()'s output - we want continuous updates on the no of finished jobs
my $orig_stdout = $|;
$| = 1;

# write all cmd line parameters and a time stamp to the log
$LOG = common::safe_open(">>$log_file");
$i = join ' ', @ARGV; $j = `date`;
print $LOG "ARGS: " . $i . " | " . $j; #print "ARGS: " . $i . " | " . $j; 

if (-e $matrix_file)

	{

	print "matrix file exists!\n";

	#DEBUG should really rather look for existing profiles, not alignments
	# populate @new_clusters
	if (! get_biggest_file_seq_count($alignments_dir, "aln", "existing alignments"))
		{ 
		die "ERROR: no clusters found!\n";
		}

	@new_clusters = sort { $a <=> $b } @new_clusters;
	
	load_matrix();
		
	}

else

	{ 

	#NOTE the only dir that has to exist before this script is run 
	#NOTE is $base_work_dir/mfasta, containing the starting clusters
	print "setting up files and directories...\n";

	common::new_dir_if_nexists($alignments_dir);
	common::new_dir_if_nexists($profiles_dir);

	common::new_dir_if_nexists($old_alignments_dir);
	common::new_dir_if_nexists($old_profiles_dir);
	common::new_dir_if_nexists($old_mfasta_dir);

	common::new_dir_if_nexists($problem_mfasta_dir);
	common::new_dir_if_nexists($problem_profiles_dir);
	common::new_dir_if_nexists($problem_alignments_dir);

	common::new_or_clear_dir($jobs_dir);
	common::new_or_clear_dir($results_dir);

	common::new_dir_if_nexists($trace_dir);
	
	# populate @new_clusters
	# if there are already alignments use those...
	if (! register_starting_clusters($alignments_dir, "aln", "existing alignments")) 
		
		{ 
		
		# ...otherwise align any existing (starting) cluster faa files			
		if (! register_starting_clusters($mfasta_dir, "faa", "clusters to align")) 
			{ die "ERROR: no starting clusters found!\n"; } 
				
		}			

	#DEBUG this is a good point to exit when debugging for problems with the starting clusters
	#exit;

	@new_clusters = sort { $a <=> $b } @new_clusters;

	if (@new_clusters > 0) 
		{ if (align_clusters() == -1) { die "ERROR: fatal error in align_clusters()!\n"; } } 
	else { print $LOG "no clusters to align\n"; }

	if (@new_clusters > 0) 
		{ if (profile_clusters() == -1) { die "ERROR: fatal error in profile_clusters()!\n"; } } 
	else { print $LOG "no profiles to generate\n"; }
	
	$pairs_matrix_offset = 0;

	init_matrix();
	
	}

@current_clusters = @new_clusters;
$current_cluster_count = @current_clusters;
@new_clusters = ();
@deleted_clusters = ();

# all those files are empty when this script is first executed on a set of 
# starting clusters (i.e., a certain superfamily sequence dataset)
system(SYSTEM_CALL_TOUCH . " $pairs_list_file");
system(SYSTEM_CALL_TOUCH . " $results_file");
system(SYSTEM_CALL_TOUCH . " $kept_results_file");
system(SYSTEM_CALL_TOUCH . " $new_kept_results_file");
system(SYSTEM_CALL_TOUCH . " $stored_results_file");

#DEBUG temp solution, better check if we have at least 2 starting clusters!
system(SYSTEM_CALL_TOUCH . " $superfamily_clustering_trace_file");
	
# ------------------------------------------------------------------------
# --MAIN LOOP-------------------------------------------------------------
# ------------------------------------------------------------------------

my $finished = 0;

my $errors = 0;

while (! $finished) 

	{ 

	# clean stdout and stderr dirs
	if ($stdout_dir ne "/dev/null") 

		{ 
		
		rmtree($stdout_dir); mkpath($stdout_dir);
		rmtree($stderr_dir); mkpath($stderr_dir);
		
		}
	
	print "ITERATION: $iteration\n"; print $LOG "ITERATION $iteration\n";

	print "$current_cluster_count total clusters\n";
	print $LOG "$current_cluster_count total clusters\n";

	print "$total_comps_left comparisons left\n";
	print $LOG "$total_comps_left comparisons left\n";
	
	# this uses $total_comps_left which is first set in init() and
	# then iteratively in update_matrix(); it is also set by load_matrix()
	calc_pairs_per_iteration();

	#DEBUG this is an optional sanity check (no. of bits set must always match no. of comparisons left!)
	#check_matrix();

	if (generate_pairs_list_file())

		{ if (compare_clusters() == -1) { die "ERROR: fatal error in compare_clusters()!\n"; } }

	# sort the results top-down (lowest evalue first)
	sort_results(); 
	# add any stored results from prior executions where a tighter (lower) cluster
	# dissimilarity threshold was set
	add_stored_results();
	# add any kept results that meet the current threshold
	# these can exist if $merges_max_per_iteration is set to st. low in merge_clusters()
	add_kept_results();
	
	# this is a 0/1 hash that says whether or not a given cluster (number) currently exists
	# it's created from @current_clusters here in each iteration, used and modified in merge_clusters() 
	# and also used in update_kept_results() and filter_stored_results() below
	$cl_bit_hash = ""; grep(vec($cl_bit_hash, $_, 1) = 1, @current_clusters);

	# merge as well as the align_clusters() and profile_clusters() subs (here due to failure to align or 
	# build a profile) can mark clusters as deleted. the list is processed in update_matrix()
	@deleted_clusters = ();
	
	$finished = merge_clusters();

	# in update_matrix these clusters will be removed from @current_clusters 
	@deleted_clusters = sort { $a <=> $b } @deleted_clusters;
		
	# keep this list (file) up-to-date; these results are kept and later stored for following
	# executions of with a more loose (higher evalue) cluster dissimilarity threshold
	update_kept_results();

	#sets $biggest_cluster_seqs and populates @new_clusters
	get_biggest_file_seq_count($mfasta_dir, "faa", "new clusters");

	@new_clusters = sort { $a <=> $b } @new_clusters;
	
	# the whole $errors thing is to have a gentle exit instead of dying when alignment or profile
	# generation fails; this can happen when the clusters get very large and cause memory problems etc;
	# in that case we stop the clustering process but still want to use all so-far produced clusters to 
	# generate the model library later on; this means the protocol after exiting with errors is the same 
	# as when exiting without errors
	$errors = 0;

	if (@new_clusters > 0) { if (align_clusters() != 0) { $errors = 1; } } else { print $LOG "no new clusters\n"; }
	
	if ($errors) { $finished = 1; next; }
	
	if (@new_clusters > 0) { if (profile_clusters() != 0) { $errors = 2; } } else { print $LOG "no new profiles\n"; }

	if ($errors) { $finished = 1; next; }
	
	# deletes clusters from @current_clusters
	update_matrix();

	# add the new clusters to the list of currently existing clusters
	@current_clusters = (@current_clusters, @new_clusters);
	$current_cluster_count = @current_clusters;

	save_matrix();

	# this is not neccessary but a good way to reduce memory usage asap
	load_matrix();

	$iteration++;
	
	}	

if (-e $inactive_stored_results_file) { common::safe_move($inactive_stored_results_file, $stored_results_file) or die "ERROR: move failed ($!)"; }

if (-e $new_kept_results_file) { unlink($new_kept_results_file); }

merge_sort_two_sorted_results_files($kept_results_file, $stored_results_file, $stored_results_file, "results to stored results");

filter_stored_results();

#DEBUG could unlink the pairs_list_file, mfasta_list_file and profiles_list_file files here!
#DEBUG could unlink matrix and matrix dim files here!

#DEBUG turn on output caching again, see above
$| = $orig_stdout;

print $LOG `date`;

if ($errors) 
	{ 
	print $LOG "ERROR: finished prematurely with error $errors!\n"; 
	close $LOG; 
	die "ERROR: finished prematurely with error $errors!\n"; 
	}
else 
	{ 
	print "FINISHED.\n"; print $LOG "FINISHED.\n"; 
	close $LOG;
	}

# -------------------------------------------------------------------------------------------------------
# --EOF-MAIN---------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------

sub init_dirs_and_files
{

	# DIRECTORIES

	#DEBUG
	$temp_dir = "$base_work_dir/temp";
	# override the default Linux temp dir
	$ENV{"TMPDIR"} = $temp_dir;
				
	$mfasta_dir = "$base_work_dir/mfasta";
	$alignments_dir = "$base_work_dir/alignments";
	$profiles_dir = "$base_work_dir/profiles";

	$jobs_dir = "$base_work_dir/jobs";
	$results_dir = "$base_work_dir/results";
	
	$trace_dir = "$base_work_dir/trace";
	
	$stdout_dir = "$base_work_dir/stdout";
	$stderr_dir = "$base_work_dir/stderr";

	$old_mfasta_dir = "$base_work_dir/old_mfasta";
	$problem_mfasta_dir = "$base_work_dir/problem_mfasta";

	$old_alignments_dir = "$base_work_dir/old_alignments";
	$problem_alignments_dir = "$base_work_dir/problem_alignments";

	$old_profiles_dir = "$base_work_dir/old_profiles";
	$problem_profiles_dir = "$base_work_dir/problem_profiles";

	# FILES
	
	$temp_file_generic = "$temp_dir/gen_temp.tmp"; # for general use
	$temp_file_merge_sort = "$temp_dir/ms_temp.tmp"; # reserved for use in merge_sort function!

	#DEBUGxxx
	$system_call_stderr_file = "$base_work_dir/system_calls.errors";

	#DEBUG this could be a single file instead, used as job input in all 
	#DEBUG cases (e.g. "tasks_to_distribute") - not done right now since 
	#DEBUG debugging is easier having these 3 files (they're only overwritten
	#DEBUG in the next iteration, respectively)
	$pairs_list_file = "$base_work_dir/pairs.thisiter";
	$mfasta_list_file = "$base_work_dir/faas.toalign";
	$profiles_list_file = "$base_work_dir/profiles.togenerate";
	
	$matrix_file = "$base_work_dir/matrix.current";
	$matrix_dimensions_file = "$matrix_file.dim";

	$results_file = "$base_work_dir/results.current";
	$kept_results_file = "$base_work_dir/results.kept";
	$new_kept_results_file = "$base_work_dir/results.tokeep";
	$stored_results_file = "$base_work_dir/results.stored";
	$inactive_stored_results_file = "$base_work_dir/results.inactive";
	
	#DEBUGxxx make 'trace' a constant, then refer to this both here
	#DEBUGxxx and in cluster_sequences.pl; same for most/all files in this sub!
	$superfamily_clustering_trace_file = "$trace_dir/merges.trace";

	$log_file = "$base_work_dir/progress.log";
	$qstat_output_file = "$base_work_dir/qstat.output";
	
}


sub init_matrix

{

	print "writing all pairs...\n";

	print $LOG "writing all pairs...\n";
	
	$total_comps_left = 0;

	@pairs_matrix = ();

	for ($i = 0; $i < @new_clusters; $i++)

		{

		$c1 = $new_clusters[$i] - $pairs_matrix_offset;

		$pairs_matrix[$c1] = "";

		for ($j = $i + 1; $j < @new_clusters; $j++)

			{

			$c2 = $new_clusters[$j] - $pairs_matrix_offset;

			vec($pairs_matrix[$c1], ($c2 - $c1), 1) = 1;

			$total_comps_left++;

			}

		}
		

	#DEBUG: important for saving the matrix later on
	foreach (@pairs_matrix) { if (!defined($_)) { $_ = ""; } }
	
	print $LOG "done.\n";

}

# -------------------------------------------------------------------------------------------------------

# this monitors a batch of submitted jobs using the qstat command, tracking how many have finished and how many are still running
# if jobs 'disappear' i.e. there are less jobs running than should this also resubmits the respective jobs
# this fills the global $done_bit_hash so after returning - in case there are jobs to resubmit - we know which
sub wait_or_prepare_resubmit

{

	my ($num_jobs, $sub_jobs) = @_;
	
	my ($t0, $waited, $stat_quo, $stat_err, $done_jobs, $last_dj, @done_files, @all_jobs, $running_jobs, $left, $job_id, $job_name, $job_num);

	$done_jobs = 0; $last_dj = 0; $stat_err = 0; 
	
	$t0 = time;
	$stat_quo = 1;
	# make sure we check at least once, initially
	$waited = common::INFINITY;

	while ($done_jobs < $num_jobs) 

		{

		if ($waited > $job_monitoring_check_interval_in_secs)

			{ 			
			
			$waited = 0;
			
			if (system(RES_MAN_CALL_QSTAT . " -u $hpc_user_name > $qstat_output_file") != 0)

				{

				if (! $stat_err) { $stat_err = 1; print "\nERROR in qstat! keep trying...\n"; }

				$t0 = time; next;

				}

			else

				# this gets the relevant jobs' info for this run from the qstat output for that user
				{ $stat_err = 0; @all_jobs = `$egrep_qs_cmd`; }

			chomp @all_jobs; 

			$running_jobs = @all_jobs;

			#DEBUG
			#if ($running_jobs == 0) { print "\nDEBUG: \@all_jobs = @all_jobs"; }

			$done_bit_hash = "";

			@done_files = @{common::safe_glob("$results_dir/done.*")};
			
			#DEBUG
			# the unless accounts for errors when reading the file (file sys errors) that can 
			# otherwise lead to a value of 0 here and thus massive resubmissions flooding the queue
			# $done_jobs = $last_dj unless ($done_jobs = @done_files);
			$done_jobs = @done_files;

			$left = $num_jobs - $done_jobs;

			# if we have waited unusually long already or there are less jobs left running than should be
			if ((! $stat_quo) || ($running_jobs < $left))

				{
	
				print "\ntotal: $num_jobs\tdone: $done_jobs\ttodo: $left\tqstat: $running_jobs ($job_prefix, $eval_threshold)\n";

				# make sure we don't keep outputting the above unless st. changes
				$stat_quo = 1; 

				}

			# get job numbers from *.done files
			foreach (@done_files)
				
				{
				
				@cols = split /\//; $i = pop @cols; $i =~ s/done\.//;

				# job has finished - no need to resubmit
				vec($done_bit_hash, $i, 1) = 1;
				
				}

			# get job numbers from qstat output, check state, and warn in case of errors
			foreach (@all_jobs)

				 {

				 @cols = split /\s+/;

				 $job_id = $cols[$qstat_job_number_col]; 
			
				 $job_name = $cols[$qstat_job_name_col]; 

				 $job_num = $job_name; $job_num =~ s/$job_prefix//;

				 # job is in error state
				 if ($cols[$qstat_job_state_col] =~ m/$qstat_error_states/) 
					{ 
					if (! $stat_quo) 
						{ print "WARNING: check job $job_num for error states!\n"; } 
					$running_jobs--; $stat_quo = 1 ; 
					}	
					
				 # job is running, queued, transferred, exiting, etc - no need to resubmit
				 else { vec($done_bit_hash, $job_num, 1) = 1; }

               	 }
	
			if ($running_jobs >= $left) 

				{ 

				#DEBUG more jobs have finished...dots would look nicer but are less 
				#DEBUG informative than the no of finished jobs
				if ($done_jobs > $last_dj) 
					{ 
					print "." x ($done_jobs - $last_dj); 
					$last_dj = $done_jobs; 
					$stat_quo = 1; 
					} 
				else 
					{
					#DEBUG
					#$stat_quo = 0; 
					}
				
				}

			# there are jobs to resubmit
			else { $submit_str = "resubmitting";  print "\n"; return 0; }
			
			$t0 = time;

			}
	
		sleep $resman_wait_after_cmd_in_secs;
			
		$waited = time - $t0; 						

		}

	# all done
	print "\n"; return 1;

}

# this submits a job of the given type for each job input file found in $job_input_dir and numbered *.0000 to *.nnnn
# it initially submits all jobs, then calls the monitoring routine, and if that comes back with jobs to resubmit it does so
# this iterative process goes on until all jobs have finished 
# note: make sure num_jobs is set accordingly and any extra parameters start 
# from a4 (e.g. "a4='1',a5=''")
# this convention must also be followed in the job script specified
sub submit_then_monitor_and_wait_for_results

{

	my ($job_type, $job_script, $node_script, $job_input_dir, $script_extra_params) = @_;

	my $res_man_command;
	
	$submit_str = "submitting";

	$done_bit_hash = "";
		
	print $LOG `date`;
	print $LOG "$job_type start\n";

	while (1)

		{

		print "$submit_str";
		print $LOG "$submit_str...";

		$sub_jobs = 0;

		for ($i = 0; $i < $num_jobs; $i++) 

			{

			if (! vec($done_bit_hash, $i, 1))

				{
		
				# the job scripts take 4 digit job numbers (i.e. job file extensions)
				$j = sprintf "%04d", $i;
		
				$flag = 0;
				
				$res_man_command = RES_MAN_CALL_QSUB . " -N $job_prefix$j -e $stderr_dir -o $stdout_dir $standard_resman_parameters $qsub_additional_params -v a1=$j,a2=$node_script,a3=$job_input_dir,$script_extra_params $job_script";
				
				while (system("$res_man_command 1>$res_man_output_goes_to") != 0) 
						
					{ 
					
						if (! $flag) 
							{ 
							print "\nERROR in qsub! keep trying...\n"; 
							$flag = 1; 
							} 
						
						sleep $resman_wait_after_cmd_in_secs; 
					
					}
		
				print ".";

				$sub_jobs++;

				sleep $resman_wait_after_cmd_in_secs;

				}

			}

		
		print "\n";
		
		#DEBUG prints the last qsub above
		#print $LOG "$res_man_command\n";
		
		sleep $resman_wait_after_cmd_in_secs;

		print "waiting for $job_type jobs...($sub_jobs submitted)\n";
		print $LOG "waiting for $job_type jobs...($sub_jobs submitted)\n";

		$flag = wait_or_prepare_resubmit($num_jobs, $sub_jobs);
		
		if ($flag) { last; } 
		else 
			{
			#DEBUG!!! not supported anymore 
			#print "reloading settings\n"; 
			
			#DEBUG this is a good place to die when debugging problems with losing
			#DEBUG jobs
			#exit;
			#DEBUG see comment above
			#xxx
			#DEBUG if $project = "" all dirs will be relative to the CWD
			#$superfamily_clustering_dir = hpcpart::init_hpc_dirs_and_files($project, $base_work_dir);
			}
		
		}

	#DEBUG	
	$flag = 0;

	#DEBUG to be safe, we delete any (double) jobs that may still be running
	#DEBUG could do this specifically, for lost jobs only, after reloading settings in above loop
	$res_man_command = RES_MAN_CALL_QDEL . " -u $hpc_user_name $job_prefix*";	

	system("$res_man_command 1>$res_man_output_goes_to");
	
	print $LOG `date`;
	print $LOG "$job_type done\n";
	
}

# this is the top-most of the job submission and monitoring routines; it prepares the job input files, calls the submit/monitor routine
# and finally processes any errors logs produced by jobs - it returns this information along with the no of total and completed jobs
# this also 'cleans up' i.e. deltes all kinds of job-related files
sub distribute

{
	
	my ($line, $count1, $count2, @error_cluster_numbers, @done_files);

	my ($task_type, $all_tasks_list, $job_size, $job_mem, $job_time, $job_script, $node_script, $job_input_dir, $job_optional_params) = @_; 

	#DEBUG could move to an old_errors dir
	unlink(<$results_dir/errors.*>) unless ($keep_all_job_stderr_files);
	
	print "distributing $task_type task...\n";

	print $LOG "distributing $task_type task...\n";

	common::safe_sys_call("split -d -a $job_no_length -l $job_size $all_tasks_list $jobs_dir/job.", "splitting jobs file");

	@jobs = @{common::safe_glob("$jobs_dir/job.*")}; $num_jobs = @jobs;

	if ($num_jobs == 0) { print "no $task_type jobs\n"; print $LOG "no $task_type jobs\n"; return (0, 0, \@error_cluster_numbers); }

	if ($job_settings_override_settings_in_job_script_files) { $standard_resman_parameters = "$qsub_mem_param=$job_mem $qsub_runtime_param=$job_time"; }
	else { $standard_resman_parameters = ""; }
		
	print "$task_type jobs: $num_jobs x $job_size\n";

	print $LOG "$task_type jobs: $num_jobs x $job_size\n";

	#DEBUG restructure so that settings for job time etc can be reloaded
	submit_then_monitor_and_wait_for_results($task_type, $job_script, $node_script, $job_input_dir, $job_optional_params);

	$i = 0; $j = 0;
	
	my @fatal_error_jobs = ();

	@done_files = @{common::safe_glob("$results_dir/done.*")};

	my $TMP;

	foreach (@done_files)

		{ 
		
		$TMP = common::safe_open("<$_"); $line = <$TMP>; close $TMP; 

		if (! $line) { $count1 = -1; }
		else { chomp $line; ($count1, $count2) = split common::DRCS, $line; }
		
		if ($count2 == -1) { chomp; @cols = split /\./, $_; push @fatal_error_jobs, $cols[-1]; } 
		else { $i += $count1; $j += $count2; }
		  
		} 

	($count1, $count2) = ($i, $j);
		
	unlink(<$results_dir/done.*>) or print "WARNING: no flag files deleted $!\n";

	unlink(<$jobs_dir/job.*>) or print "WARNING: no job files deleted $!\n";
	
	# jobs can produce $nnnn.$ext.stderr (ext is an extension set in the job 
	# script) files for each execution of the respective binary, i.e., 
	# for each line of the job's input file		
	my @error_files = @{common::safe_glob("$results_dir/*.stderr")};

	foreach (@error_files) 
	
		{ 
		
		# get job number, e.g. 0000 in .../results/0000.aln.stderr
		chomp; @cols = split /\//; $i = pop @cols; @cols = split /\./, $i; $j = $cols[-3]; 

		$TMP = common::safe_open("<$_"); $exit_code = <$TMP>; close $TMP; 

		if (! $exit_code) { push @fatal_error_jobs, $j; }

		else 

			{

			chomp $exit_code;
	
			print "ERROR $exit_code in $task_type job, input file no: $j\n"; print $LOG "ERROR $exit_code in $task_type job, input file no: $j\n";
			push @error_cluster_numbers, $j;
			
			}
	
		} 

	foreach (@fatal_error_jobs) 
	
		{
	
		print "ERROR fatal/sigerror in $task_type job, job no: $_\n"; print $LOG "ERROR fatal/sigerror in $task_type job, job no: $_\n"; 
		
		# -1 flag for: at least one job killed by a SIGXCPU signal 
		# (look at *.job scripts for more info)
		($count1, $count2) = (0, -1); 
		
		}

	#NOTE we do this above now, so that we can still process errors after this sub
	#unlink(<$results_dir/errors.*>) unless ($keep_all_job_stderr_files);
		
	print $LOG "done.\n";

	return ($count1, $count2, \@error_cluster_numbers);

}

# this moves erroneous or problematic job output files to special folders and deletes any affected (starting) clusters from the hashes
# so that they do not take part in clustering (they wouldn't have either a proper alignment and/or a proper profile as there were errors)
sub process_errors

{

	my ($ref, $in_sig, $out_sig, $in_dir, $prob_in_dir, $out_dir, $prob_out_dir) = @_;

	my @error_cluster_numbers = @{$ref};
	
	my $errors = 0;

	foreach my $number (@error_cluster_numbers)
	
		{
		
		$errors++;

		# move job input files to the dedicated 'problem job' directory if there 
		# was an error with the job
		if (-e "$in_dir/$number.$in_sig") 
			{ 
			common::safe_move("$in_dir/$number.$in_sig", $prob_in_dir) or die "ERROR: move failed $!";
			}
		elsif (-e "old_$in_dir/$number.$in_sig")
			{
			common::safe_move("old_$in_dir/$number.$in_sig", $prob_in_dir) or die "ERROR: move failed $!";
			}
	
		# ...sometimes there is (erroneous) output too, do the same here
		if (-e "$out_dir/$number.$out_sig") 
			{ common::safe_move("$out_dir/$number.$out_sig", $prob_out_dir) or die "ERROR: move failed $!"; }

		#DEBUG it's only a single file but move() can't glob (?)
		#@cols = <$stderr_dir/$job_prefix$number.*>;
		#foreach (@cols)
		#	{ common::safe_move($_, $prob_out_dir) or die "ERROR: move failed $!"; }
		
		# ...same for the job's stderr output
		if (-e "$results_dir/$errors.$number")
			{ common::safe_move("$results_dir/$errors.$number", $prob_out_dir) or die "ERROR: move failed $!"; }

		# remove that cluster from the list of new clusters
		@new_clusters = grep { $_ != $number } @new_clusters;
		# and mark it as deleted
		push @deleted_clusters, $number;		
		
		}

	# return number of errors
	return $errors;

}

# -------------------------------------------------------------------------------------------------------

sub align_clusters

{

	my $TMP = common::safe_open(">$mfasta_list_file"); foreach (@new_clusters) { print $TMP "$_\n"; } close $TMP;
	
	$align_job_size = int($align_max_job_size / $biggest_cluster_seqs);
	if ($align_job_size < $align_min_job_size) { $align_job_size = $align_min_job_size; }
 
	#NOTE for job script parameters that have internal spaces (e.g. a5 here), inverted
	#NOTE commas must be used as here to pass them, or the job will fail
	my ($aligned, $total, $efile_list_ref) = 
	distribute("align", $mfasta_list_file, $align_job_size, $align_job_mem, $align_job_time, $align_job_script, $align_script, $base_work_dir, "a4=$mafft_executable,a5='$mafft_hq_params',a6='$mafft_lq_params',a7=$mafft_aln_quality_seq_num_cutoff");

	# SIG error
	if ($total == -1) { return -1; }

	#DEBUG should this be moved behind process_errors() below?
	if ($aligned == 0) { return 0; }

	my $errors = process_errors($efile_list_ref, "faa", "aln", $mfasta_dir, $problem_mfasta_dir, $results_dir, $problem_alignments_dir);

	#DEBUG replace by safe_move and/or safe_glob calls?	
	common::safe_sys_call("find $results_dir/ -type f -name '*.aln' -exec mv -f {} $alignments_dir/ \\;", "moving alignment files");

	#DEBUG could do this at later point, after processing any profile or compare errors
	common::safe_sys_call("find $mfasta_dir/ -type f -name '*.faa' -exec mv -f {} $old_mfasta_dir/ \\;", "moving cluster files");

	return $errors;
	
}	


sub profile_clusters

{

	my $TMP = common::safe_open(">$profiles_list_file"); foreach (@new_clusters) { print $TMP "$_\n"; } close $TMP;
	
	$profile_job_size = int($profile_max_job_size / $biggest_cluster_seqs);
	if ($profile_job_size < $profile_min_job_size) { $profile_job_size = $profile_min_job_size; }

	my ($generated, $total, $efile_list_ref) = 
	distribute("profile", $profiles_list_file, $profile_job_size, $profile_job_mem, $profile_job_time, $profile_job_script, $profile_script, $base_work_dir, "a4=$compass_executable,a5='$compass_params'");

	# SIG error
	if ($total == -1) { return -1; }

	if ($generated == 0) { return 0; }

	my $errors = process_errors($efile_list_ref, "aln", "prof", $alignments_dir, $problem_alignments_dir, $results_dir, $problem_profiles_dir);

	#DEBUG see above
	common::safe_sys_call("find $results_dir/ -type f -name '*.prof' -exec mv -f {} $profiles_dir/ \\;", "moving profile files");
	
	return $errors;
	
}	
	

sub compare_clusters

{

	#DEBUG gotta make sure pairs file has been generated - move generate_pairs_list_file to here at one point

	# since profile-profile comparison does not take much longer (?) for large 
	# clusters than for small ones we can get away with this (unlike in the 
	# previous to subs for aligning and profiling)
	$compare_job_size = $compare_max_job_size;
	
	my ($compared, $better_than_cutoff, $efile_list_ref) = 
	distribute("compare", $pairs_list_file, $compare_job_size, $compare_job_mem, $compare_job_time, $compare_job_script, $compare_script, $base_work_dir, "a4=$eval_threshold,a5=$compass_dbXdb_executable,a6='$compass_params'");
	
	#DEBUG make changes to the compare job script to catch compass_db2db errors (there shouldn't be any apart from timeout maybe)
	
	#SIGnal error (a job resource limit such as CPU time or memory has been exceeded)
	if ($better_than_cutoff == -1) { return -1; }
	
	if ($compared == 0) { return 0; }
	
	#DEBUG this wouldn't make sense - rather think about what to do with 2 clusters if comparing their profiles fails
	#process_errors($efile_list_ref, "aln", "aln", $mfasta_dir, $problem_alignments_dir, $results_dir, $problem_alignments_dir);
	
	print $LOG "total and better than cutoff: $compared, $better_than_cutoff\n";
	
	if ($better_than_cutoff == 0) { print "cutoff reached!\n"; print $LOG "cutoff reached!\n"; }

	return 0;

}	
	
# -------------------------------------------------------------------------------------------------------

# this fills @new_clusters
sub register_starting_clusters

{

	#DEBUG make the following globals local at one point
	# those clusters newly added in a round
	@new_clusters = (); 	
	# those clusters removed in a round
	@deleted_clusters = ();

	my ($cluster_dir, $clus_file_ext, $file_type) = @_;

	my ($cluster, $cluster_count, $seq_count, $total_seq_count, $highest_seq_count) = (0, 0, 0, 0, 0);

	print "checking $file_type...\n"; print $LOG "checking $file_type...\n";
	
	my @clus_files = @{common::safe_glob("$cluster_dir/*\.$clus_file_ext")};
	
	foreach $faa_file (@clus_files)
	
		{
		
		$cluster_count++;
	
		$seq_count = fasta::count_headers_in_faa_file($faa_file);
		$total_seq_count += $seq_count;
		if ($seq_count > $highest_seq_count) { $highest_seq_count = $seq_count; }

		# this gets the cluster no from the file name 
		$cluster = common::strip_path_and_extension($faa_file);
		push @new_clusters, $cluster;

		#DEBUG just to see some progress, newline follows below
		if ($cluster_count % 1000 == 0) { print "."; }
		
		}
	
	#DEBUG change this
	if ($cluster_count >= 1000) { print "\n"; }

	my $outstr = "done. ($cluster_count clusters, $total_seq_count sequences)\n";
	print $outstr;	print $LOG $outstr;
	
	$biggest_cluster_seqs = $highest_seq_count;

	return $highest_seq_count;

}

# -------------------------------------------------------------------------------------------------------

sub generate_pairs_list_file

{

	if ($pairs_this_iteration == 0) { print "no pairs left to compare!\n"; return 0; }

	print "compiling $pairs_this_iteration pairs...\n";
	print $LOG "compiling $pairs_this_iteration pairs...\n";

	$k = 0;

	my $PF = common::safe_open(">$pairs_list_file");

	if ($pairs_this_iteration == $total_comps_left)

		{
		
		for ($i = 0; $i < $current_cluster_count - 1; $i++)
		
			{
			
			for ($j = $i + 1; $j < $current_cluster_count; $j++)
			
				{ 
				
				$c1 = $current_clusters[$i]; $c2 = $current_clusters[$j];
	
				if (!vec($pairs_matrix[$c1 - $pairs_matrix_offset], ($c2 - $c1), 1)) { next; }
			
				vec($pairs_matrix[$c1 - $pairs_matrix_offset], ($c2 - $c1), 1) = 0;

				$pair = sprintf "$pair_template\n", $c1, $c2; #$pair = $c1 . "\t" . $c2 . "\n";		
				print $PF $pair;
				
				#DEBUG not necessary
				$k++;
				
				}

			}		
		
		#print "generated: $k\n";

		}
		
	else
	
		{

		#DEBUG: update this section from sub below!
		while ($k < $pairs_this_iteration)

			{

			# we want a random pair where $c2 > $c1

			# random cluster no 1
			$i = int(rand($current_cluster_count - 1));

			$j = $i + 1;

			# random cluster no 2, always greater no than no 1
			$j += int(rand($current_cluster_count - $j));

			$c1 = $current_clusters[$i]; $c2 = $current_clusters[$j];

			if (!vec($pairs_matrix[$c1 - $pairs_matrix_offset], ($c2 - $c1), 1)) { next; }

			# flag pair as used

			vec($pairs_matrix[$c1 - $pairs_matrix_offset], ($c2 - $c1), 1) = 0;

			$pair = sprintf "$pair_template\n", $c1, $c2; #$pair = $c1 . "\t" . $c2 . "\n";		

			#DEBUG experimental, in case of failure!
			#if (! -e "$alignments_dir/$c1.aln") { common::safe_move("$old_alignments_dir/$c1.aln", $alignments_dir); }
			#if (! -e "$alignments_dir/$c2.aln") { common::safe_move("$old_alignments_dir/$c1.aln", $alignments_dir); }

			print $PF $pair;

			$k++;

			}
			
		}
	
	close $PF;	

	print $LOG "done\n";

	return 1;

}

sub generate_pairs_list_file_using_centers

{

	print "compiling $pairs_this_iteration pairs (head node)...\n";

	print $LOG "compiling $pairs_this_iteration pairs (head node)...\n";
	
	my $min_centers = 10;
	
	my $current_centers = int($current_cluster_count / 100);

	if ($current_centers < $min_centers) 
	
		{ if ($current_cluster_count >= $min_centers) { $current_centers = $min_centers; } else { $current_centers = $current_cluster_count; } }
	
	print "centers: $current_centers\n";

	my @targets = @current_clusters;
	
	my %centers;

	my $number_bit_hash = ""; 
	
	foreach (0..$current_cluster_count) { vec($number_bit_hash, $_, 1) = 1; }
		
	print "chosing centers...\n";

	$k = 0;
		
	#DEBUG: we could try to not repeat recently used centers
	# generate 
	while ($k < $current_centers)
	
		{
		
		$i = int(rand($current_cluster_count));
		
		if (! vec($number_bit_hash, $i, 1)) { next; } 
		
		vec($number_bit_hash, $i, 1) = 0;

		$c1 = $current_clusters[$i];
		
		$centers{$c1} = 1;
		
		$k++;
		
		}

	# remove centers from targets	
	@targets = grep { ! exists $centers{$_} } @targets;
		
	my @centers = sort { $a <=> $b } keys %centers;
		
	my $current_targets = @targets;
	
	print "targets: $current_targets\n";

	#DEBUG: total number of pairs written
	$k = 0;

	print "writing center-target pairs...\n";

	my $PF = common::safe_open(">$pairs_list_file");
	
	# compile all uncompared center:target pairs
	foreach (@centers)
	
		{
		
		$c2 = $_ - $pairs_matrix_offset;
		
		foreach (@targets)
		
			{
			
			$c1 = $_ - $pairs_matrix_offset;
		
			if ($c1 > $c2) { $i = $c2; $j = $c1 - $c2; } else { $i = $c1; $j = $c2 - $c1; }

			if (! vec($pairs_matrix[$i], $j, 1)) { next; }
			
			vec($pairs_matrix[$i], $j, 1) = 0;
			
			if ($c2 > $c1) { $pair = sprintf "$pair_template\n", $c1, $c2; } else { $pair = sprintf "$pair_template\n", $c2, $c1; }

			print $PF $pair;

			$k++;

			}
			
		}
	
	# DEBUG it might work without this!
=cut	
	
	print "$k pairs written so far\n";

	print "writing random pairs...\n";	
	
	# fill the rest with randomly selected uncompared pairs from targets
	while ($k < $pairs_this_iteration)

		{

		# DEBUG: was using current_targets in the following, but now current_clusters -> center:center pairs are possible!
		# we want a random pair where $c2 > $c1
		$i = int(rand($current_cluster_count - 1));

		$j = $i + 1; 
		
		$j += int(rand($current_cluster_count - $j));

		$c1 = $current_clusters[$i]; $c2 = $current_clusters[$j];
		
		$i = $c1 - $pairs_matrix_offset; $j = $c2 - $c1;
						
		if (! vec($pairs_matrix[$i], $j, 1)) { next; }

		# flag pair as used

		vec($pairs_matrix[$i], $j, 1) = 0;

		$pair = sprintf "$pair_template\n", $c1, $c2; #$pair = $c1 . "\t" . $c2 . "\n";		

		print $PF $pair;

		$k++;

		#if ($k % 100000 == 0) { print "$k\n"; }

		}
		
=cut

	close $PF;	
	
	print "$k total pairs written\n";

	print $LOG "done\n";
	
	#DEBUG could be more...
	$pairs_this_iteration = $k;

}

sub calc_pairs_per_iteration
{

	# we only make a fraction of the number of remaining possible comparisons
	# in each iteration - this script has been developed with a setting
	# of 1%
	$pairs_this_iteration = int($total_comps_left * $comparisons_fraction_of_all_per_iteration);

	# however, we also set upper and lower boundaries to the value calculated above,
	# primarily to keep the runtimes of individual compare jobs within a reasonable range

	if ($pairs_this_iteration > $comparisons_max_per_iteration) 
		{ $pairs_this_iteration = $comparisons_max_per_iteration; }
	elsif ($pairs_this_iteration < $comparisons_min_per_iteration) 
		{ $pairs_this_iteration = $comparisons_min_per_iteration; }
	
	# there might be less comparisons than comparisons_min_per_iteration left
	if ($pairs_this_iteration > $total_comps_left) 
		{ $pairs_this_iteration = $total_comps_left; }
		
}

# -------------------------------------------------------------------------------------------------------

sub update_matrix

{

	my ($rem, $add) = (0, 0);
	
	print "updating the matrix...\n";

	print $LOG "updating the matrix...\n";

	# both cluster lists have to be sorted and the DELETED ones still MUST BE IN @current_clusters so that all pair deletions are recorded
	# NEWLY CREATED clusters MUST NOT already BE IN @current_clusters at this point

	foreach (@deleted_clusters)

		{

		$c2 = $_ - $pairs_matrix_offset;

		# remove all current:del pairs - current_clusters still contains deleted ones too (see above)
		foreach (@current_clusters)

			{
			
			$c1 = $_ - $pairs_matrix_offset;

			if ($c1 == $c2) { next; }

			# also remove del:current pairs
			if ($c1 > $c2) { $i = $c2; $j = $c1 - $c2; } else { $i = $c1; $j = $c2 - $c1; }

			# any comparison could already have been made in prior iterations, only count deletion if it's still there
			if (vec($pairs_matrix[$i], $j, 1) == 1)	{ vec($pairs_matrix[$i], $j, 1) = 0; $rem++; }

			}

		}

	
	# free some memory by deleting matrix rows of deleted clusters
	foreach $c1 (@deleted_clusters) 
	
		{ 
				
		# remove deleted cluster from @current_clusters
		@current_clusters = grep { $_ != $c1 } @current_clusters; 
		
		$pairs_matrix[$c1 - $pairs_matrix_offset] = ""; 
		
		};

	#DEBUG can be 0 at this point!
	$current_cluster_count = @current_clusters;

	#DEBUG this we can move to the main loop
	@deleted_clusters = ();

	# add current:new pairs

	foreach (@current_clusters)

		{

		$c1 = $_ - $pairs_matrix_offset;

		foreach (@new_clusters)

			{

			$c2 = $_ - $pairs_matrix_offset;

			# new cluster no is always > old cluster no
			vec($pairs_matrix[$c1], ($c2 - $c1), 1) = 1; $add++;			

			}

		}

	# add new:new pairs
	
	# new cluster no is always > old cluster no
	for ($i = 0; $i < @new_clusters; $i++)

		{

		$c1 = $new_clusters[$i] - $pairs_matrix_offset;

		$pairs_matrix[$c1] = "";

		for($j = $i + 1; $j < @new_clusters; $j++)

			{

			$c2 = $new_clusters[$j] - $pairs_matrix_offset;

			vec($pairs_matrix[$c1], ($c2 - $c1), 1) = 1; $add++;		
			
			}

		}
	
	$total_comps_left = $total_comps_left - $pairs_this_iteration + $add - $rem;

	print $LOG "done. ($rem comparisons removed, $add added)\n";
	
}

sub save_matrix

{

	print "saving matrix... \n";

	print $LOG "saving matrix...\n";

	#DEBUG GETRID
	foreach (@pairs_matrix) { if (!defined($_)) { $_ = ""; }}

	my $TMP = common::safe_open(">$matrix_dimensions_file");
	
	my $TMP2 = common::safe_open(">$matrix_file");

	$k = $current_clusters[0];

	$l = $current_clusters[-1] - $pairs_matrix_offset;

	#print "$k $l $pairs_matrix_offset\n";

	print $TMP "$total_comps_left\n$current_cluster_count\n$k\n";

	$k -= $pairs_matrix_offset;
	
	{ use bytes; # for length() to know it's not chars eg unicode ones>1 byte!

	for ($i = $k; $i <= $l; $i++)

		{ $j = $pairs_matrix[$i]; print $TMP length($j) . "\n"; print $TMP2 $j; }
	
	}
	
	close $TMP2;
	
	close $TMP;
	
	print $i-$k . " rows written \n";

	print $LOG "done. " . ($i-$k) . " rows written \n";

}

sub load_matrix

{

	print "loading matrix...\n";

	print $LOG "loading matrix...\n";

	@cols = ();

	my $TMP = common::safe_open("<$matrix_dimensions_file");

	$total_comps_left = <$TMP>; $current_cluster_count = <$TMP>; $pairs_matrix_offset = <$TMP>;
	
	map(chomp, ($total_comps_left, $current_cluster_count, $pairs_matrix_offset));
	
	# cause it was $lcn when saved
	$pairs_matrix_offset--;
	
	while (<$TMP>) { chomp; push @cols, $_; }		
		
	close $TMP;

	@pairs_matrix = ();

	$TMP = common::safe_open("<$matrix_file");

	$i = 0;	$j = "";

	foreach (@cols)
	
		{ 
		
		if (read($TMP, $j, $_) != $_) { print "ERROR in matrix file: too small!\n"; } 
		
		$pairs_matrix[$i+1] = $j; $i++; 
		
		#print "$i $l $k\n";
		
		}

	# this is a sanity check: try reading a single byte, if it's possible there's st. wrong!
	if (read($TMP, $j, 1) != 0) { print "ERROR in matrix file: too big!\n"; } 

	close $TMP;
	
	undef @cols;

	print "$i rows read\n";
	
	print $LOG "done. " . $i . " rows read \n";
	
}

sub check_matrix

{ 
	
	$i = 0;

	foreach (@current_clusters)
	
		{
		
		$c1 = $_ - $pairs_matrix_offset;
		
		foreach (@current_clusters)
		
			{

			$c2 = $_ - $pairs_matrix_offset;
			
			if ($c2 <= $c1) { next; }

			if (vec($pairs_matrix[$c1], ($c2 - $c1), 1) == 1) 
			
				{ 

				$i++; 				
												
				#print ".";
				
				$flag = 1;
								
				} 
				
			else 
			
				{ 
				
				#print " "; 
				
				}
				
			} 
			
		#print "\n";
			
		} 
	

	print "matrix bits set: $i\n";
	
	print $LOG "matrix bits set: $i\n";

}

# ---------------------------------------------------------------------------------------------

# this is used by add_kept_results() and add_stored_results()
sub merge_sort_two_sorted_results_files

{

	my ($f1, $f2, $outf, $str) = @_;
	
	print "adding $str (head node)...\n";

 	print $LOG "adding $str (head node)...\n";

	# sort by third column (E-value)
	common::safe_sys_call("sort -m -gk3 -T $temp_dir -S $sort_big_sort_mem $f1 $f2 > $temp_file_merge_sort", "merge-sorting $f1 and $f2");

	# one of them could point to $outf, so do rm those first!
	unlink($f1, $f2);

	common::safe_move($temp_file_merge_sort, $outf) or die "ERROR: move failed $!";

	print $LOG "done.\n";

}

#DEBUG: this could be replaced by a faster (?) merge-sort with following scan for pairs to be removed; 
#this uses globals for file names (could be params instead) and the globals $tab and $infinity
sub update_kept_results
{

	print "updating kept results...\n"; print $LOG "updating kept results...\n";

	#DEBUG if file is empty there is nothing to do
	if (! -s $new_kept_results_file) { return; }

	my ($pair, $new_pair, $c1, $c2) = ("", "", 0, 0); 
	my ($evalue, $new_evalue) = (0, common::INFINITY);

	my $NKRF = common::safe_open("<$new_kept_results_file");

	# skip any results that meet the _current_ threshold - these are still to be 
	# used in following iterations and not to be stored for following executions;
	# see the $merges_max_per_iteration setting in merge_clusters() for more info
	# we don't count such pairs as removed pairs as we do with the ones further down
	while (<$NKRF>)
		
		{
		
		$new_pair = $_; 
		($c1, $tab, $c2, $tab, $new_evalue) = unpack($score_unpack_template, $new_pair);		
		if ($new_evalue > $eval_threshold) { last; }
		
		}
	
	# is end of new pairs file reached? both 'flags' are neccessary for flow control below!
	if ($new_evalue <= $eval_threshold) { $new_pair = ""; $new_evalue = common::INFINITY; }
	
	my $KRF = common::safe_open("<$kept_results_file");
	my $TMP = common::safe_open(">$temp_file_generic");

	my ($now_kept, $removed) = (0, 0);

	# this omits all old pairs where >0 clusters do not exist anymore and
	# merges in new pairs, keeping up the sort order (evalue)
	while (<$KRF>) 

		{ 

		$pair = $_; 		
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $pair);
		$c1 = int($c1); $c2 = int($c2);
		
		# do both old clusters still exist? if not skip them!
		if (!vec($cl_bit_hash, $c1, 1) || !vec($cl_bit_hash, $c2, 1)) { $removed++; next; }

		# write new pairs until old eval is better, by definition all clusters in new pairs
		# do exist, so that does not need to be checked for
		while ($new_evalue < $evalue)
			
			{
			
			# write new pair
			print $TMP $new_pair; $now_kept++;
			
			$new_pair = <$NKRF>;
			# is end of new pairs file reached?
			if (!$new_pair) { $new_evalue = common::INFINITY; last; }
			# we actually only need $new_evalue here
			($c1, $tab, $c2, $tab, $new_evalue) = unpack($score_unpack_template, $new_pair);	
			
			}
			
		# write old pair
		print $TMP $pair; $now_kept++;

		}

	# one new pair could still be 'cached', see above
	if ($new_pair) { print $TMP $new_pair; $now_kept++; }
	# further new pairs could be left at this point
	while (<$NKRF>) { print $TMP $_; $now_kept++; }

	close $TMP; close $KRF; close $NKRF;
	# replace original by new, filtered file
	unlink($kept_results_file);
	common::safe_move($temp_file_generic, $kept_results_file) or die "ERROR: move failed $!";

	print $LOG "done. ($removed removed, $now_kept now kept)\n";

}

=comment
This adds any kept results produced by prior iterations (where the same threshold was set) that meet the current cluster dissimilarity threshold to the current results list
=cut
sub add_kept_results
{

	# if file is empty there is nothing to do
	if (! -s $new_kept_results_file) { return; }

	print "adding kept results...\n";
	print $LOG "adding kept results...\n";

	my $TMP = common::safe_open(">$temp_file_generic");

	my $added = 0;
	
	my $KRF = common::safe_open("<$new_kept_results_file");

	# collect all stored results that meet the _current_ cluster dissimilarity threshold
	# the results in this file are sorted top-down (lowest evalue first)
	while (<$KRF>)
		
		{
		
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $_);
		if ($evalue > $eval_threshold) { last; }		
		print $TMP $_;
		$added++;
		
		}

	close $KRF;
	close $TMP;

	# add these results to the current results (those just generated by comparing clusters)
	# merge_sort means the results as a whole remain sorted doing this
	merge_sort_two_sorted_results_files($temp_file_generic, $results_file, $results_file, "kept to current results");

	unlink($new_kept_results_file);
	
	print $LOG "done. ($added results added)\n";

}

# ---------------------------------------------------------------------------------------------

=comment
This takes the file with all stored results accumulated at a given point and 
filters out all results that have been used (i.e. that meet the current cluster 
dissimilarity threshold) and any results of comparisons involving clusters no 
longer existing. The file is then up-to-date (and smaller), and can be loaded at 
the start of the next execution where a more loose (higher) cluster dissimilarity 
threshold is set.
=cut
sub filter_stored_results
{

	# if file is empty there is nothing to do
	if (! -s $stored_results_file) { return; }

	print "updating stored results...\n"; print $LOG "updating stored results...\n";

	my $SRF = common::safe_open("<$stored_results_file");

	my $removed = 0; 
	my ($pair, $c1, $c2, $evalue) = ("", 0, 0, 0);
	
	# filter 1: omit all results that meet the _current_ threshold; these have been used and
	# we will not need them anymore
	while (<$SRF>)
	
		{
	
		$pair = $_; 
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $pair);			
		if ($evalue > $eval_threshold) { last; }
		$removed++;
	
		}
		
	# at this point $pair is defined, undef it if there are no stored results left
	if ($evalue <= $eval_threshold) { undef $pair; }

	my $TMP = common::safe_open(">$temp_file_generic");
	while ($pair) 
	
		{ 
	
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $pair);
		$c1 = int($c1); $c2 = int($c2);
		# filter 2: both clusters have to still exist to be included in the filtered file
		if (vec($cl_bit_hash, $c1, 1) && vec($cl_bit_hash, $c2, 1)) 
			{ $i++; print $TMP $pair; } else { $removed++; }
		$pair = <$SRF>;
	
		}
	
	close $TMP; close $SRF;

	# replace original by new, filtered file
	unlink($stored_results_file);
	common::safe_move($temp_file_generic, $stored_results_file) or die "ERROR: move failed $!";

	print $LOG "done. ($removed removed)\n";

}

#DEBUG this is a duplicate of add_kept_results, could make it one and use parameters instead!
=comment
This adds any stored results produced in prior executions 
(where a stricter threshold was set) that meet the current cluster 
dissimilarity threshold to the current results list
=cut
sub add_stored_results
{

	# if file is empty there is nothing to do
	if (! -s $stored_results_file) { return; }

	print "adding stored results...\n";
	print $LOG "adding stored results...\n";

	my $TMP = common::safe_open(">$temp_file_generic");

	my $added = 0;
	
	my $SRF = common::safe_open("<$stored_results_file"); 

	# collect all stored results that meet the _current_ cluster dissimilarity threshold
	# the results in this file are sorted top-down (lowest evalue first)
	while (<$SRF>)
		{
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $_);
		if ($evalue > $eval_threshold) { last; }		
		print $TMP $_;
		$added++;
		}

	close $SRF;
	close $TMP;

	# add these results to the current results (those just generated by comparing clusters)
	# merge_sort means the results as a whole remain sorted doing this
	merge_sort_two_sorted_results_files($temp_file_generic, $results_file, $results_file, "stored to current results");

	common::safe_move($stored_results_file, $inactive_stored_results_file) or die "ERROR: move failed ($!)";

	print $LOG "done. ($added results added)\n";

}

# ---------------------------------------------------------------------------------------------

sub sort_results

{
	print "sorting the results (head node)...\n";

	print $LOG "sorting the results (head node)...\n";

	$j = 0;

	my @results_files = @{common::safe_glob("$results_dir/results.*")};
	
	foreach (@results_files)

		{

		@cols = split /\./;

		$i = pop @cols;
		
		common::safe_sys_call("sort -gk3 -T $temp_dir -S $sort_small_sort_mem $_ > $results_dir/results_sorted.$i", "sorting file");
	
		$j++;

		}

	print $LOG "done.\n";

	# --------------------------------------------------

	print "merge-sorting the results (head node)...\n";

	print $LOG "merge-sorting the results (head node)...\n";

	common::safe_sys_call("find $results_dir -name 'results_sorted.*' -exec cat {} \\; | sort -gk3 -T $temp_dir -S $sort_big_sort_mem - > $results_file", "sorting results files");

	unlink(<$results_dir/results.*>); # or print "WARNING: no files deleted $!\n";

	unlink(<$results_dir/results_sorted.*>); # or print "WARNING: no files deleted $!\n";
	
}

# -------------------------------------------------------------------------------------------------------

# this is the key sub for the clustering process
sub merge_clusters

{

	my ($output, $new_clus_num, $merge_count, $merge_recursions, $a1, $a2, $term, 
	$cluster, $terms1, $terms2,	@terms1, @terms2, @terms, $merged, $is_subset);

	# used in recursive merging (see below)
	my %map_old_clus_to_new = ();
	
	print "merging cluster files (head node)...\n";
	print $LOG "merging cluster files (head node)...\n";

	my $TMP = common::safe_open("<$results_file");

	# always start naming of new clusters with highest cluster number + 1
	$new_clus_num = $current_clusters[-1] + 1;

	$evalue = -1;

	$merge_count = 0;

	while (<$TMP>) 

		{ 

		# get pair and score from results file
		$pair = $_;
		($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $pair);
		$c1 = int($c1); $c2 = int($c2);
	
		# we only merge pairs that meet the current similarity cutoff
		if ($evalue > $eval_threshold) { last; }

		#DEBUG we might wanna get rid of the recursive merging feature again and excise the following code, 
		#DEBUG it's proven to mess up the clustering to much, and is disabled by default anyway
		#DEBUG ($merges_max_recursions = 1)

# ---------- START of code that needs to be changed if recursive merging feature shall be removed --------------
		
		# this is set to infinity by default (the merging heuristic), ideal hierarchical
		# clustering would be a single merge per round
		if ($merge_count == $merges_max_per_iteration) { last; }

		# recursive merging is based on recursing through a linked list (tree) of merged clusters 
		# (this loop alters $c1 and $c2!) - it is an experimental 3rd heuristic
		foreach my $cluster ($c1, $c2)
			{
			$merge_recursions = 0;
			while (exists $map_old_clus_to_new{$cluster}) 
				{ $cluster = $map_old_clus_to_new{$cluster}; $merge_recursions++; }
			if ($merge_recursions > $merges_max_recursions) { $cluster = "none"; }
			}
		
		# either cluster may have undergone too many recursions above or both clusters have ended up
		# in the same cluster already; $evalue is set to 0 as a flag in case we reach the end of the
		# $TMP file
		if (($c1 eq "none" || $c2 eq "none") || ($c1 eq $c2)) { $evalue = -1; next; }
		
		#DEBUG this part can be replaced by 2 "move" lines if recursive merging is de-implemented
		# this deals with the faa, aln and prof files for both clusters to be merged
		foreach my $cluster ($c1, $c2)
			{

			# cluster still exists
			if (vec($cl_bit_hash, $cluster, 1)) 
				{ 	
				
				vec($cl_bit_hash, $cluster, 1) = 0; push @deleted_clusters, $cluster;

				# during recursions above we don't actually align the 'intermediate' clusters
				if (! -e "$alignments_dir/$cluster.aln") { next; }

				common::safe_move("$alignments_dir/$cluster.aln", $old_alignments_dir) or die "ERROR: move failed $!";
				common::safe_move("$profiles_dir/$cluster.prof", $old_profiles_dir) or die "ERROR: move failed $!";
				} 
			
			# cluster has already been merged
			else
				{ 
				
				# if one of the clusters has already been merged 1+ times in this round the
				# file is moved already
				if (-e "$mfasta_dir/$cluster.faa") 
					{ common::safe_move("$mfasta_dir/$cluster.faa", $old_mfasta_dir) or die "ERROR: move failed $!"; }
				
				}
			}

		#DEBUG only needed for recursive merging, see above
		# this creates new nodes in the linked list of merged clusters 
		$map_old_clus_to_new{$c1} = $new_clus_num;
		$map_old_clus_to_new{$c2} = $new_clus_num;

		#DEBUG further check above and below for minor bits of related code in case of removal

# ---------- DEBUG end of code that needs to be changed if recursive merging feature shall be removed --------------

		# write merged faa file
		common::safe_sys_call("cat $old_mfasta_dir/$c1.faa $old_mfasta_dir/$c2.faa > $mfasta_dir/$new_clus_num.faa", "merging cluster files");
		
		#DEBUG to save space on the file system we do no longer keep those
		unlink("$old_mfasta_dir/$c1.faa", "$old_mfasta_dir/$c2.faa");
		unlink("$old_alignments_dir/$c1.aln", "$old_alignments_dir/$c2.aln");
		unlink("$old_profiles_dir/$c1.prof", "$old_profiles_dir/$c2.prof");
		
		#DEBUG removed M's and none's that were used previously
		#$output = "$c1\t(none)\tnone\t$evalue\t$new_clus_num\tM\n$c2\t(none)\tnone\t$evalue\t$new_clus_num\tM\n";	
		
		$output = $c1 . DWCS . $c2 . DWCS . $new_clus_num . DWCS . $evalue . "\n";
			
		my $TMP2 = common::safe_open(">>$superfamily_clustering_trace_file");
	        print $TMP2 $output;
       		close $TMP2;
		
		$merge_count++;

		$new_clus_num++;

		}

	my $NKRF = common::safe_open(">$new_kept_results_file");

	# $evalue is -1 here if there are no results (left) to store (see above)
	if ($evalue > -1)
		{ 
		# store any results that do not meet the current cluster dissimilarity threshold for 
		# following executions, where a looser (higher evalue) threshold will be set	
		# at this point $c1, $c2 and $evalue are defined (see before "last;" in loop above)
		while (1)
			{
			# filter: both clusters have to still exist after the above merging
			if (vec($cl_bit_hash, $c1, 1) && vec($cl_bit_hash, $c2, 1)) { print $NKRF $pair; }
			# read the next pair and check for EOF
			$pair = <$TMP>; if (! $pair) { last; }
			($c1, $tab, $c2, $tab, $evalue) = unpack($score_unpack_template, $pair);
			$c1 = int($c1); $c2 = int($c2);
			}
		}
	
	close $NKRF;

	close $TMP;
	
	print $LOG "done. ($merge_count new clusters, " . @deleted_clusters . " deleted clusters) \n";

	# if nothing merged
	if ($merge_count == 0) { return 1; }

	return 0;

}

# -------------------------------------------------------------------------------------------------------

sub get_biggest_file_seq_count

{

	my ($dir, $ext, $file_type) = @_;

	print "checking $file_type...\n";

	print $LOG "checking $file_type...\n";

	my $TMP = common::safe_open_dir($dir);
	@new_clusters = sort {-s "$dir/$a" <=> -s "$dir/$b"} grep(/\.$ext/, readdir($TMP));
	closedir $TMP;

	$i = @new_clusters; $j = "-"; $k = "-";

	if ($i > 0)
	
		{
		
		$k = $dir . "/" . $new_clusters[-1];
		
		$j = (-s $k);

		$k  = `grep -c ">" $k`; chomp $k;

		$j = sprintf "%02.f", $j / 1024;

		} 
		
	print $LOG "done. ($i $file_type, biggest file: $j kb ($k sequences))\n";
	
	# keep numeric part of filename (suffix) only 
	map(s|\D||g, @new_clusters);
	
	$biggest_cluster_seqs = $k;
	#return $k;

}

# -------------------------------------------------------------------------------------------------------
