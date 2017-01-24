#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

#NOTE this uses template.sh as a universal POSIX job script for batch job submission
#NOTE posix_batch_job.sh calls $script and passes through the parameters as follows
#NOTE $script is usually a Perl script, e.g., 'something.pl'

#NOTE posix_batch_job.sh takes parameters in the following fashion (without newlines):
#NOTE "$script_full_path $project $superfamily $overwrite_mode $run_id $ork_dir";

#DEBUG $additional_parameters is not used anymore
#NOTE $additional_parameters is a comma-separated list of values that is 
#NOTE (as most of the other parameters) passed through to $script

#NOTE have a look at posix_batch_job.sh to better understand the calling/script hierarchy
#NOTE essentially it's 3 tiers: this script, posix_batch_job.sh and the respective 
#NOTE script that is being called

#NOTE different instances of $script effectively run in parallel
#NOTE within $script, one or more slave scripts may be called in a serial manner,
#NOTE respectively; that is, some scripts are 'wrappers' for a batch of others

use strict;

use FindBin qw ($Bin); use lib "$Bin/../modules";
use common;
#DEBUG the use if pragma and eval doesn't seem to work...for now we use both
use localpart;
use hpcpart;

use List::Util 'shuffle';


common::check_args(\@ARGV, 10, "project script work_dir superfamily_list_file " .
							   "superfamily_size_file min_sf_size max_sf_size " .
							   "max_sfs max_instances overwrite? " .
							   "[optional_script_parameters]");
#DEBUG!!! was "none"
my $optional_script_parameters = common::check_opt_args(\@ARGV, 11, "");

my ($project, $script, $work_dir, $superfamilies_list_file, $superfamilies_size_file, $min_sf_size, 
	$max_sf_size, $max_sfs, $max_instances, $overwrite_mode) = @ARGV;

	
#DEBUG could fix those in common.pm
my $batch_stdout_dir = "$work_dir/output";
my $batch_stderr_dir = "$work_dir/errors";

#DEBUG	
#if (-d $batch_stdout_dir) { die "ERROR: $batch_stdout_dir already exists! (remove and retry?)\n"; }
	
#DEBUG
#my $overwrite_mode = "no";

common::load_settings(common::PIPELINE_CONFIG_FILE_NAME, 1); 
common::check_host();

if ($local_run) 
	{ 
	localpart::init_local_dirs_and_files($project, "none");	
	} 
else 
	{ 
	hpcpart::init_hpc_dirs_and_files($project, "none");	
	}

check_disk_space();
	
common::new_dir_if_nexists($work_dir);
common::new_dir_if_nexists($batch_stdout_dir);
common::new_dir_if_nexists($batch_stderr_dir);

#DEBUG to be safe
unlink <$work_dir/*.finished>;

#DEBUGxxx
#my $superfamilies_done_file = common::strip_path_and_extension("$superfamilies_list_file");
my $superfamilies_done_file = "superfamilies";
$superfamilies_done_file = "$work_dir/$superfamilies_done_file.done";

#DEBUG could move those to common.pm
my $batch_job_script = "$batch_scripts_dir/posix_batch_job.sh";
my $wait_till_next_check = 5;

#DEBUG in conjunction with $cmd_prefix this can be used if there is more than one
#DEBUG compute node to be used
my %head_nodes = ($host_name, 0); 
#DEBUG this can be used to ssh into a compute node different from the current one
my $cmd_prefix = "";

# specific 
my (%sf_size_by_code, @superfamilies, $superfamily, $cmd,
	$head_node, $running, $pref_node, $run_id, $running_sfs, $sf_counter, $sf_size);

# generic
my (@cols, $TMP, $i, $j);

my %run_ids;
for ($i = 0; $i < ($max_instances * (keys %head_nodes)); $i++)
	{ $run_ids{$i} = 0; }
	
#DEBUG instead of a cmd line para we could use $project_superfamilies_list_file
if (! -e $superfamilies_list_file)
	{
	die "ERROR: $superfamilies_list_file not found!\n";
	}
@superfamilies = @{common::load_list($superfamilies_list_file)};

if (! -e $superfamilies_size_file)
	{
	die "ERROR: $superfamilies_size_file not found!\n";
	}
	
%sf_size_by_code = %{common::load_hash_with_scalar_value($superfamilies_size_file, DRCS)};


sub check_disk_space
{

	#NOTE this is now switched off via the settings in pipeline.config
	return;

	#use Carp qw/ confess /;

	#confess "base_data_dir not defined" unless defined $base_data_dir;
	#confess "base_data_dir_min_free_blocks not def" unless defined $base_data_dir_min_free_blocks;
	#confess "base_data_dir_max_percent_usage not def" unless defined $base_data_dir_max_percent_usage;

	if (! common::disk_space_ok($base_data_dir, $base_data_dir_min_free_blocks, $base_data_dir_max_percent_usage))
		{ die "ERROR: insufficient disk space in $base_data_dir!\n"; }

	if (! common::disk_space_ok($base_work_dir, $base_work_dir_min_free_blocks, $base_work_dir_max_percent_usage))
		{ die "ERROR: insufficient disk space in $base_work_dir!\n"; }
		
	#DEBUGxxx should check quotas on specific drives (where we use dirs)?
	if (! common::disk_quota_ok($base_data_dir_min_free_blocks, $base_data_dir_max_percent_usage))
		{ die "ERROR: insufficient disk space quota!\n"; }	

}


sub check_finished_jobs
{

	# the *.finished file is created as a flag by the $batch_job_script script
	# when a family has been finished processing and all output has been stored 
	# file name format: hostname_nn_3.40.50.720.finished, where nn = instance code
	foreach (@{common::safe_glob("$work_dir/*.finished")})
	
		{
			
		$i = common::strip_path_and_extension($_, "finished");
	
		# file name uses "_" as separator for bits of information
		@cols = split /\_/, $i;
		
		#DEBUG see how $host_name is derived in common.pm, make this a sub
		my $head_node = $cols[0];
		my @cols2 = split /\./, $head_node;
		$head_node = $cols2[0];		

		#DEBUG for single submit host version
		if ($head_node ne $host_name) { next; }

		$head_nodes{$head_node}--;
		
		$run_id = $cols[1];
		# free this instance code
		$run_ids{$run_id} = 0;
		
		$superfamily = $cols[2];
										
		$running_sfs--;

		unlink $_;

		$i = common::get_date();
		
		print "finished superfamily $superfamily on $head_node at $i\n";
		system(SYSTEM_CALL_ECHO . " $superfamily >> $superfamilies_done_file");
	
		}

}


if (! -e $superfamilies_done_file) { system(SYSTEM_CALL_TOUCH . " $superfamilies_done_file"); }
	
# randomise order of families to process
@superfamilies = shuffle @superfamilies;

$running_sfs = 0;
$sf_counter = 0;
$pref_node = "";

my $waiting = 0;

foreach $superfamily (@superfamilies)

	{
				
	# the family must not be done already
	my $cmd = SYSTEM_CALL_GREP;
	$i = `$cmd \^$superfamily\$ $superfamilies_done_file`; chomp $i;
	if ($i) { next; }

	# the superfamily must be defined
	if (! exists $sf_size_by_code{$superfamily})
		{
		print "WARNING: superfamily $superfamily is not defined!\n";
		#DEBUG to keep numbers in infile and donefile even, and this message 
		#DEBUG from reappearing
		system(SYSTEM_CALL_ECHO . " $superfamily >> $superfamilies_done_file");
		next;
		}

	$sf_size = $sf_size_by_code{$superfamily};
	# check superfamily size constraint	
	if ($sf_size < $min_sf_size ||  $sf_size > $max_sf_size) { next; }
		
	print "waiting for free slot on head node(s)...\n";
	
	while (1)
	
		{

		check_finished_jobs();
					
		$i = 0; $j = 1000;

		$pref_node = "";
		
		# check which submit node has the fewest running families
		foreach (keys %head_nodes)	

			{

			$i = $head_nodes{$_}; 

			if ($i < $j) { $j = $i; $pref_node = $_; }

			#print "$_ : $i\t";

			}
		
		if ($j < $max_instances) { $waiting = 0; last; } 

		else 

			{
 
			if (! $waiting) 
				{ 
				print "all nodes fully occupied, waiting $wait_till_next_check seconds...\n"; 
				$waiting = 1; 
				} 
			sleep($wait_till_next_check); 

			}
		
		}
				
	#print "\n";

	print "least ($j) instances on: $pref_node\n";
	
	#DEBUG should do this only every half hour or so
	check_disk_space();

	foreach (keys %run_ids) { if ($run_ids{$_} == 0) { $run_id = sprintf "%02.d", $_; $run_ids{$_} = 1; last; } } # take code
	
	# the called script must take (or ignore) parameters in the following fashion:
	$cmd = "$batch_job_script $scripts_dir/$script $project $superfamily $overwrite_mode $run_id $work_dir $optional_script_parameters";

	if ($pref_node !~ /$host_name/) { $cmd = "$cmd_prefix $pref_node $cmd"; } 
	
	$i = common::get_date();
	
	print "starting instance $run_id for $superfamily ($sf_size) on $pref_node at $i...\n";
		
	# this spawns a new background process
	system(SYSTEM_CALL_NOHUP . " $cmd & >/dev/null 2>/dev/null"); #>> $superfamily.output 2>>$superfamily.errors &");
	
	$running_sfs++;
	
	$head_nodes{$pref_node}++; 

	#NOTE the *.running files are checked by dfx.pl when using the 'check' command
	# this file is to quickly check the last process started on the respective node	
	system(SYSTEM_CALL_ECHO . " $superfamily\t$sf_size\t$cmd > $work_dir/$pref_node.running");
	
	$sf_counter++;	

	if ($sf_counter >= $max_sfs) { last; }

	}
	
# ------------------------------------------------------------------------------------------

$waiting = 0;

while (1)

	{

	# format: comp1_nn_3.40.50.720.finished, where comp1 = headnode, nn = instance cod

	check_finished_jobs();

	foreach (keys %head_nodes)	

		{

		$i = $head_nodes{$_}; 

		#print "$_ : $i\t";

		}

	#print "\n";

	if ($running_sfs == 0) { $waiting = 0; last; } 
	
	else 
		
		{  
		
		if (! $waiting) 
			{ 
			print "waiting for $running_sfs instances to complete, checking every $wait_till_next_check seconds...\n"; 
			$waiting = 1; 
			} 
		
		sleep($wait_till_next_check); 
		
		}

	}
				
foreach (keys %head_nodes)
	{
	#NOTE the *.running files are checked by dfx.pl when using the 'check' command
	if (-e "$work_dir/$_.running") { unlink "$work_dir/$_.running"; }
	}
