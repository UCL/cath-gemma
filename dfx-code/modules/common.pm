#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package common;

#TODO prefix things consistently everywhere, e.g., "$project_starting_cluster_data_dir"
#TODO instead of "$starting_cluster_data_dir"; means change in many modules/scripts
#TODO replace all instances of `date` by common::get_date()
#TODO make all instances of die() report FATAL ERROR instead of ERROR

use strict;
use warnings;

use File::Glob qw (GLOB_ERR GLOB_ERROR bsd_glob);
use File::Copy qw (move copy);
use File::Path qw (mkpath rmtree);

use Carp qw/ confess cluck /;

our $VERSION = '1.00';
use base 'Exporter';

our @EXPORT = 

qw

(

	SYSTEM_CALL_CD
	SYSTEM_CALL_CAT
	SYSTEM_CALL_ECHO
	SYSTEM_CALL_COPY
	SYSTEM_CALL_MV
	SYSTEM_CALL_MKDIR
	SYSTEM_CALL_TOUCH
	SYSTEM_CALL_CUT
	SYSTEM_CALL_LNS
	
	SYSTEM_CALL_SORT_UNIQUE
	SYSTEM_CALL_SED
	SYSTEM_CALL_GREP
	SYSTEM_CALL_EGREP
	
	SYSTEM_CALL_WGET 
	SYSTEM_CALL_CURL 

	SYSTEM_CALL_TAR
	SYSTEM_CALL_GZIP 
	SYSTEM_CALL_GUNZIP 
	
	SYSTEM_CALL_NOHUP
	SYSTEM_CALL_QUOTA
	SYSTEM_CALL_DF
	SYSTEM_CALL_HOSTNAM
	SYSTEM_CALL_DATE

	SEQ_HEADER_ID_SEPARATOR
	SEQ_HEADER_COORD_SEPARATOR 
	SEQ_HEADER_SEGMENT_SEPARATOR
	SEQ_HEADER_CORE_SEPARATOR 
	SEQ_HEADER_SFCODE_SEPARATOR
	SEQ_HEADER_SFCODE_COLUMN

	FAA
	HMM
	
	SFS
	SIZES
	PERSF
	
	ANNO
	GREPPED
	NAMES
	TAXIDS
	LENGTHS
	EXCLUDED
		
	GZ
	
	TO_UNIPROT_IDS
	SPROT
	ANNO_TO
	
	DWCS
	DRCS

	STDOUT_REDIRECT
	
	$date_stamp
	
	$host_name
	
	$hpc_submit_node
	$hpc_ssh_target_node
	$local_ssh_target_node
	$local_run

	$datasources_config_file
	$clustering_config_file
	$annotations_config_file
	$thirdpartytools_config_file
	$hpcjob_config_file
	$default_project_config_file
	$project_config_file
		
	$base_work_dir
	$local_base_work_dir
	$hpc_base_work_dir
	
	$base_data_dir
	$local_base_data_dir
	$hpc_base_data_dir

	$local_user_name
	$hpc_user_name
	
	$base_data_dir_min_free_blocks
	$base_data_dir_max_percent_usage
	
	$base_work_dir_min_free_blocks
	$base_work_dir_max_percent_usage
	
	$scripts_dir
	
	$batch_scripts_dir
	$wrapper_scripts_dir
	$tools_dir
	
	$shared_data_dir
	$raw_shared_data_dir
	$processed_shared_data_dir
	$used_shared_data_dir

	$idmappings_data_dir
	
	$persf_seq_dataset
	$persf_seq2ukb_dataset
	$persf_seq2go_dataset
	
	$projects_data_dir	
	$project_data_dir

	$project
	$projects_work_dir
	$project_work_dir
	
	$family_set
	$family_granularity
	
	$temp_data_dir
	$temp_dir
	
	$starting_cluster_data_dir
	$starting_cluster_dir
	
	$clustering_output_data_dir
	$superfamily_clustering_trace_file

	$go_ontology_hash_file_set

	$ukb_taxonomy_hash_file_set
	
	$superfamilies_list_file
	$superfamilies_size_file

	$superfamilies_custom_list_file
	
	$starting_clusters_min_seqs
	$starting_clusters_min_anno_fraction
	
	$starting_clusters_seq_length_lower_N_percent_excluded
	$starting_clusters_seq_length_upper_N_percent_excluded
	$starting_clusters_seq_max_homopoly_percent
	$starting_clusters_seq_min_ok_split_dom_percent

	@go_root_terms
	@go_deprecated_terms
	@go_unreliable_mf_branches
	
	$dendrogram_min_branch_length
	$dendrogram_max_branch_length
	
	$mafft_base_dir
	$mafft_executable
	
	$compass_base_dir
	$compass_executable
	$compass_dbXdb_executable
		
	$hmmer_base_dir
	$hmmer_build_executable
	$hmmer_search_executable
	$hmmer_press_executable
	$hmmer_scan_executable

	$cdhit_base_dir
	$cdhit_executable	

	$compass_params
	
	$mafft_aln_quality_seq_num_cutoff
	$mafft_hq_params
	$mafft_lq_params
	
	$hmmer_search_cutoff
	$hmmer_CPU_cores_used

	$cdhit_precluster_params
	$cdhit_nonredcluster_params
	
	$job_settings_override_settings_in_job_script_files
	
	@clustering_granularity_steps
	
	$comparisons_fraction_of_all_per_iteration
	
	$merges_max_per_iteration
	
	$align_job_script
	$profile_job_script
	$compare_job_script
	
	$align_script
	$profile_script
	$compare_script
	
	$compare_min_job_size
	$compare_max_job_size
	$compare_job_time
	$compare_job_mem
	
	$profile_min_job_size
	$profile_max_job_size
	$profile_job_time
	$profile_job_mem
	
	$align_min_job_size
	$align_max_job_size
	$align_job_time
	$align_job_mem
	
	$qsub_mem_param
	$qsub_runtime_param
	$qsub_additional_params
	
	$qstat_job_name_prefix
	
	$qstat_run_states
	$qstat_pending_states
	$qstat_error_states
	
	$qstat_job_number_col
	$qstat_job_name_col
	$qstat_job_state_col
	
	$qstat_username_before_jobname
	
	$qstat_user_job_grep
	
	$job_monitoring_check_interval_in_secs
	
	$resman_wait_after_cmd_in_secs
	
	$system_call_stderr_file
	
	$raw_data_ukb_webservice_seqdb_url
	$raw_data_ukb_webservice_taxdb_url

	$raw_data_go_ftp_url
	$go_ontology_oboxml_file

	$raw_data_ukbgoa_ftp_url
	$ukbgoa_gene_association_file

	$raw_data_g3d_ftp_url
	$g3d_ukb_assignments_file
	
);


# GENERIC PARAMETERS - used in the HPC and local parts of the pipeline
our 

(

	$date_stamp,

	#DEBUG we could detect this automatically
	# POSIX username, norm. the same on all local and HPC machines; important for dir names / job monitoring
	$host_name,

	$local_user_name,
	$hpc_user_name,
	
	$hpc_submit_node,
	$hpc_ssh_target_node,
	$local_ssh_target_node,
	$local_run,
	
	$base_data_dir_min_free_blocks,
	$base_data_dir_max_percent_usage,
	
	$base_work_dir_min_free_blocks,
	$base_work_dir_max_percent_usage,
	
	# CONFIG FILES

	# all these configuration files are mandatory, apart from project_config_file
	$datasources_config_file,
	$clustering_config_file,
	$annotations_config_file,
	$thirdpartytools_config_file,
	$hpcjob_config_file,
	$default_project_config_file,
	$project_config_file,

	# DIRECTORIES

	# the base working directory of GeMMA
	$base_work_dir,
	# the paths can differ
	$local_base_work_dir,
	$hpc_base_work_dir,
	
	# the base data directory of GeMMA
	# (contains different subdirs on the local and HPC systems, only some are shared)
	$base_data_dir,
	# the paths can differ
	$local_base_data_dir,
	$hpc_base_data_dir,
	
	$scripts_dir,
	
	# contains batch scripts called by batch_process_superfamilies.pl
	$batch_scripts_dir,
	$wrapper_scripts_dir,
	
	# contains 3rd party and other small tools called by the scripts in $local_scripts_dir
	$tools_dir,
	
	# this is the project name and has to match a subdirectory in the projects directory
	$project,	
	# this contains the specific project data directories
	$projects_data_dir,	
	# this contains input and output data specific to the project
	$project_data_dir,
	
	$projects_work_dir,
	$project_work_dir,

	$family_set,
	$family_granularity,

	$temp_data_dir,
	$temp_dir,
	
	$starting_cluster_data_dir,
	$starting_cluster_dir,

	$clustering_output_data_dir,

	$superfamilies_list_file,
	$superfamilies_size_file, 
	
	$superfamilies_custom_list_file,
	
	$superfamily_clustering_trace_file,
	
	# 3rd PARTY TOOLS SETTINGS
	
	$mafft_base_dir,
	$mafft_executable,
	
	# the MAFFT documentation recommends to do faster but slightly less 
	# accurate alignments when there are more than 200 sequences to align; 
	# with more CPU speed this might change...
	$mafft_aln_quality_seq_num_cutoff,
	# ...accordingly, there are two modes in which we use the tool depending 
	# on the no of seqs to align (high quality and fast)
	$mafft_hq_params,
	$mafft_lq_params,

	# any system call errors redirected to here - overwrite in main as required
	$system_call_stderr_file,
	
);

# HPC PART PARAMETERS - parameters used in the HPC part of the pipeline only, set in the cluster_config.pm file
our 

(

	# DIRECTORIES
	
	$compass_base_dir,
	$compass_executable,
	$compass_dbXdb_executable,
	
	# JOB SCRIPTS
	
	# each job type has a job script which is qsub'ed...
	$align_job_script,
	$profile_job_script,
	$compare_job_script,

	# ...and a script that does the actual job, executed in the job script on the node 
	$align_script,
	$profile_script,
	$compare_script,

	# HEURISTICS
	
	# the clustering granularity settings (COMPASS cluster dissimilarity thresholds) for subsequent rounds
	# of hierarchical clustering with GeMMA; these are E-values from min to max
	@clustering_granularity_steps,
	
	# the following specify the boundaries for the comparison heuristic; 
	# these settings must be checked whenever job runtime limits are 
	# changed below; they should be kept the same for all families in 
	# e.g. one DB update process; this version of DFX was developed 
	# and benchmarked with a setting of 1% and a min/max no of comparisons 
	# of 2,000,000 and 10,000,000, respectively; with more starting clusters 
	# and thus more comparisons this heuristic is expected to have a more
	# negative effect on the exactness of the hierarchical clustering 
	# process
	$comparisons_fraction_of_all_per_iteration,
	$comparisons_min_per_iteration,
	
	# the merging heuristic is on by default (merge as many pairs per round as you can, not just e.g. 1)
	$merges_max_per_iteration, 
	
	# JOB RESOURCE LIMITS

	$job_settings_override_settings_in_job_script_files,
	
	$compare_min_job_size,
	$compare_max_job_size,
	$compare_job_time,
	$compare_job_mem,
	
	$profile_min_job_size,
	$profile_max_job_size,
	$profile_job_time,
	$profile_job_mem,
	
	$align_min_job_size,
	$align_max_job_size,
	$align_job_time,
	$align_job_mem,
	
	# JOB SUBMISSION AND MONITORING 
	
	# these two have to be set and the format will vary between different resource managers (SGE, PBS/Torque...)
	$qsub_mem_param,
	$qsub_runtime_param,
	# any additional parameters
	$qsub_additional_params,
	
	# a freely chosen prefix for the unique job name (e.g. "rref" in "rref990001" where 99 is the family run code and 0001 the job number)
	$qstat_job_name_prefix,
	
	# each of the following is a regexp containing qstat states such as "R" and "Eq", these should be the same for any implementation of qstat
	$qstat_run_states,
	$qstat_pending_states,
	$qstat_error_states,
	
	# the following have to be set according to the observed qstat output format (column number where the respective value is found), currently 0,2,4 for SGE
	$qstat_job_number_col,
	$qstat_job_name_col,
	$qstat_job_state_col,
	
	# this is the default output format in PBS/Torque, turned off for SGE
	$qstat_username_before_jobname,
	
	# a regexp built in the configuration file to qstat for all jobs of the given user
	$qstat_user_job_grep,
	
	# if no jobs have finished in a while (this interval) we check what's going on
	$job_monitoring_check_interval_in_secs,
	
	# give qsub and qstat some time after each execution, usually 1 second is enough to prevent errors
	$resman_wait_after_cmd_in_secs,
	
	# 3rd PARTY TOOLS SETTINGS
	
	$compass_params

);

# LOCAL PART PARAMETERS - parameters used in the local part of the pipeline only, set in the local_config.pm file
our 

(

	# this contains input data that is potentially shared between projects
	$shared_data_dir,
	$raw_shared_data_dir,
	$processed_shared_data_dir,
	$used_shared_data_dir,
	
	$idmappings_data_dir,

	$persf_seq_dataset,
	$persf_seq2ukb_dataset,
	$persf_seq2go_dataset,
	
	# MISC SETTINGS
	
	# used when small clusters are to be excluded, default is 0
	$starting_clusters_min_seqs,
	# when a dataset should not be processed using the supervised protocol
	# unless at least this fraction of all starting clusters is annotated, 
	# default 0
	$starting_clusters_min_anno_fraction,
	
	$starting_clusters_seq_length_lower_N_percent_excluded,
	$starting_clusters_seq_length_upper_N_percent_excluded,
	$starting_clusters_seq_max_homopoly_percent,
	$starting_clusters_seq_min_ok_split_dom_percent,

	$dendrogram_min_branch_length,
	$dendrogram_max_branch_length,
	
	# ANNOTATION DATA RELATED SETTINGS

	# a master file name from which hash file names are derived in annotations.pm
	$go_ontology_hash_file_set,
			
	# a master file name from which hash file names are derived in taxonomy.pm
	$ukb_taxonomy_hash_file_set,
				
	# the root terms of the three GO DAGs
	@go_root_terms,
	# deprecated terms are ignored even if there are only unreliable terms (see above) for a 
	# sequence, they are effictively treated just like the root terms
	@go_deprecated_terms,
	# used to exclude certain GO MF DAG branches in assessing cluster function 
	# conservation given that other terms are available
	@go_unreliable_mf_branches,
	
	# 3rd PARTY TOOLS SETTINGS
	
	$cdhit_base_dir,
	$cdhit_executable,

	$cdhit_precluster_params,
	$cdhit_nonredcluster_params,

	$hmmer_base_dir,
	$hmmer_build_executable,
	$hmmer_search_executable,
	$hmmer_press_executable,
	$hmmer_scan_executable,
	
	$hmmer_search_cutoff,
	$hmmer_CPU_cores_used,
	
	$raw_data_ukb_webservice_seqdb_url,
	$raw_data_ukb_webservice_taxdb_url,

	$raw_data_go_ftp_url,
	$go_ontology_oboxml_file,

	$raw_data_ukbgoa_ftp_url,
	$ukbgoa_gene_association_file,

	$raw_data_g3d_ftp_url,
	$g3d_ukb_assignments_file
	
);

# CONSTANTS - usually (see below) not exported to the main namespace

use constant
{

	# this is automatically located by searching up the directory tree
	PIPELINE_CONFIG_FILE_NAME => "pipeline.config",

	# these have to be in the directory where the above file is found too
	DATA_SOURCES_CONFIG_FILE_NAME => "datasources.config",
	ANNOTATIONS_CONFIG_FILE_NAME => "annotations.config",

	THIRDPARTYTOOLS_CONFIG_FILE_NAME => "3rdparty.config",

	CLUSTERING_CONFIG_FILE_NAME => "clustering.config",
	HPCJOB_CONFIG_FILE_NAME => "hpcjobs.config",

	#DEBUG no longer in use!
	DEFAULT_PROJECT_CONFIG_FILE_NAME => "default_project.config",

	# optionally found in the project-specific work directory
	PROJECT_CONFIG_FILE_NAME => "project.config"
	
};

use constant
{

	DATASET_NAME_PER_SF => "persf",
	
	DOMSEQ_DATA_DIR_PREFIX => "domseq_data_",
	UNIPROT_DATA_DIR_PREFIX => "uniprot_data_",
	GO_DATA_DIR_PREFIX => "go_data_",

	SF_LIST_FILE_NAME_EXTENSION => "sfs",
	SF_SIZE_FILE_NAME_EXTENSION => "sizes",
	PROJECT_SUPERFAMILIES_LIST_FILE_NAME => "superfamilies.list",
	PROJECT_SUPERFAMILIES_SIZE_FILE_NAME => "superfamilies.sizes",
	
	PROT_ID_TO_UKB_ACC_FILENAME_LINKER => "to_uniprot_ids",
	SPROT_FILENAME_SIGNATURE => "sprot",
	SEQ_TO_ANNO_FILENAME_LINKER => "anno_to",
	
	FASTA_FILE_NAME_EXTENSION => "faa",
	HMM_FILE_NAME_EXTENSION => "hmm",
	
	ANNO_FILE_NAME_EXTENSION => "anno",
	NAMES_FILE_NAME_EXTENSION => "names",
	TAXIDS_FILE_NAME_EXTENSION => "taxids",
	LENGTHS_FILE_NAME_EXTENSION => "lenghts",
	EXCLUDED_FILE_NAME_EXTENSION => "excluded",
	
	GZIP_FILE_NAME_EXTENSION => "gz",

	GREPPED_FILE_NAME_EXTENSION => "grepped",
		
	UNIPROT_SPROT_ID_LIST_FILE_NAME => "uniprot_sprot.accs",
	UNIPROT_FRAGMENT_ID_LIST_FILE_NAME => "uniprot_fragment.accs",
	UNIPROT_TAXONOMY_FILE_NAME => "uniprot_taxonomy.tdl",
	UNIPROT_ACC2NAME_FILE_NAME => "uniprot_acc2name.tdl",
	UNIPROT_ACC2TAXON_FILE_NAME => "uniprot_acc2taxon.tdl",
	UNIPROT_ACC2LENGTH_FILE_NAME => "uniprot_acc2length.tdl"
	
};

use constant 
{ 
 
	FAMILY_DIR_NAME_SEPARATOR => "\_", 
	DEFAULT_READ_COL_SEPARATOR => qr/\s+/, 
	DEFAULT_WRITE_COL_SEPARATOR => "\t", 

	# this is the core header section, with only seq id and coords
	SEQ_HEADER_ID_SEPARATOR => qr/[\/]/,
	SEQ_HEADER_COORD_SEPARATOR => "\-" ,
	SEQ_HEADER_SEGMENT_SEPARATOR => "\_",
	# this separates the core (prot id plus dom coords) from the non-core 
	# (additional info such as superfamily etc) header section
	SEQ_HEADER_CORE_SEPARATOR => " ",
	# the sf code is found enclosed by separators in the non-core part
	#DEBUGxxx may need to change
	SEQ_HEADER_SFCODE_SEPARATOR => "[()]", #qr/[()]/,
	# this column no refers to after splitting the full header by the 
	# separator(s) above 
	SEQ_HEADER_SFCODE_COLUMN => 1
		
};

use constant 
{

	#NOTE these are Linux commands used throughout, in system() executions
	SYSTEM_CALL_CD => "cd",
	SYSTEM_CALL_CAT => "cat",
	SYSTEM_CALL_ECHO => "echo",
	SYSTEM_CALL_COPY => "cp",
	SYSTEM_CALL_MV => "mv -f",
	SYSTEM_CALL_MKDIR => "mkdir",
	SYSTEM_CALL_TOUCH => "touch",
	SYSTEM_CALL_CUT => "cut",
	SYSTEM_CALL_LNS => "ln -s",
	
	SYSTEM_CALL_SORT_UNIQUE => "sort -u",
	SYSTEM_CALL_SED => "sed",
	SYSTEM_CALL_GREP => "grep",
	SYSTEM_CALL_EGREP => "egrep",
	
	SYSTEM_CALL_WGET => "wget --quiet",
	SYSTEM_CALL_CURL => "curl --silent",
	
	SYSTEM_CALL_TAR => "tar",
	SYSTEM_CALL_GZIP => "gzip",
	SYSTEM_CALL_GUNZIP => "gunzip",
	
	SYSTEM_CALL_NOHUP => "nohup",
	SYSTEM_CALL_QUOTA => "quota",
	SYSTEM_CALL_QUOTA_LINE_TO_CHECK => -1, 
	SYSTEM_CALL_DF => "df  -P -k", 
	SYSTEM_CALL_DF_LINE_TO_CHECK => -1,
	SYSTEM_CALL_HOSTNAME => "hostname",
	SYSTEM_CALL_DATE => "date"
	
};

use constant
{

	# this is used as a timeout for POSIX system calls, such as filesys ops 
	# (e.g. in case of NFS trouble)
	SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY => 1800,  

	# this is good for debugging purposes, defaults to /dev/null
	STDOUT_REDIRECT => "/dev/null",
	
	# we initialise vars with that at times, also useful as a generic flag value
	INFINITY => 0xFFFFFF
	
};

# ------

# these are just abbreviations for the above - exported to the main namespace
use constant 

{ 

	DWCS => DEFAULT_WRITE_COL_SEPARATOR,
	DRCS => DEFAULT_READ_COL_SEPARATOR,

	SFS => SF_LIST_FILE_NAME_EXTENSION,
	SIZES => SF_SIZE_FILE_NAME_EXTENSION,
	SPROT => SPROT_FILENAME_SIGNATURE,
	TO_UNIPROT_IDS => PROT_ID_TO_UKB_ACC_FILENAME_LINKER,
	ANNO_TO => SEQ_TO_ANNO_FILENAME_LINKER,
	
	FAA => FASTA_FILE_NAME_EXTENSION,
	HMM => HMM_FILE_NAME_EXTENSION,

	ANNO => ANNO_FILE_NAME_EXTENSION,
	NAMES => NAMES_FILE_NAME_EXTENSION,
	LENGTHS => LENGTHS_FILE_NAME_EXTENSION,
	TAXIDS => TAXIDS_FILE_NAME_EXTENSION,
	EXCLUDED => EXCLUDED_FILE_NAME_EXTENSION,

	GZ => GZIP_FILE_NAME_EXTENSION,

	GREPPED => GREPPED_FILE_NAME_EXTENSION,

	PERSF => DATASET_NAME_PER_SF
	
};

# the reasoning here is that the DFX dir tree is 3 levels deep at most, so we
# search for the main (pipeline) config file in the following directories, relative
# to the current work directory; from the information in this file the paths to
# all other config files (see above) can be constructed (no searching necessary)
our @config_file_search_dirs = qw ( . .. ../.. ../../.. ../../../.. );
# this is for files that have a fully specified (i.e. known) path already 
push @config_file_search_dirs, "";
	
# this sets several global parameters exported by this module, using the specified 
# project configuration file
sub load_settings
{

	my ($config_file, $mandatory) = @_;
	
	sub find_file
		{
		my $file = shift;
		my $path = "none";
		foreach (@config_file_search_dirs) 
			{ 
			if ( -e "$_/$file") 
				{ $path = $_; last; } 
			}
		return $path;
		}
			
		
	my $path = find_file($config_file);
	
	if ($path eq "none") 
	
		{ 

		if ($mandatory)
		
			{ die "ERROR: $config_file not found!\n"; } 
			
		else 
			
			{ 
			#print "$config_file not found\n"; 
			return 0; 
			}
				
		}

	$config_file = "$path/$config_file";
		
	#DEBUG
	#print "loading settings in $config_file...\n";

	unless (my $return = do $config_file) 
		
		{
		
		warn "couldn't parse $config_file: $@"	if $@;
		warn "couldn't do $config_file: $!"	unless defined $return;
		warn "couldn't run $config_file"	unless $return; 
		
		return 0;
		
		}
		
	do { return 1; }
	
}


sub check_host
{

	my $cmd = SYSTEM_CALL_HOSTNAME;
	$host_name = `$cmd`; chomp $host_name;
	
	#DEBUG take only the machine's name (everything before the first dot)
	my @cols = split /\./, $host_name;
	$host_name = $cols[0];
	
	#DEBUG this is one of several nonideal ways to check if we're on the local or
	#DEBUG on the HPC system - could also be user input
	if ($hpc_submit_node =~ /^$host_name/) { $local_run = 0; } else { $local_run = 1; }
	cluck "hostname: $host_name, hpc_submit_node: $hpc_submit_node, local_run: $local_run";
}


# this initialises all globally (local and HPC part of pipeline) used paths; 
sub init_generic_dirs_and_files
{
	
	#DEBUG this makes this sub unusable for, e.g., install() in dfx.pl
	#if (! -d $base_work_dir) 
	#	{ die "ERROR: DFX base work directory $base_work_dir not found!\n"; }

	# DIRECTORIES
	
	$batch_scripts_dir = "$base_work_dir/batch_scripts";
	$wrapper_scripts_dir = "$base_work_dir/wrapper_scripts";
	
	$tools_dir = "$base_work_dir/tools";

	$shared_data_dir = "$base_data_dir/shared";
	$raw_shared_data_dir = "$shared_data_dir/raw";
	$processed_shared_data_dir = "$shared_data_dir/processed";
	$used_shared_data_dir = "$shared_data_dir/used";
		
	$idmappings_data_dir = "$raw_shared_data_dir/id_mapping_data";
		
	$projects_data_dir = "$base_data_dir/projects";	
	
	$projects_work_dir = "$base_work_dir/projects";

	#DEBUG do checks in calling scripts instead
	#if (! -d $project_data_dir) { die "ERROR: project $project not found!\n"; }
		
	# CONFIG FILES
	
	$datasources_config_file = "$base_work_dir/" . DATA_SOURCES_CONFIG_FILE_NAME;
	$clustering_config_file = "$base_work_dir/" . CLUSTERING_CONFIG_FILE_NAME;
	$annotations_config_file = "$base_work_dir/" . ANNOTATIONS_CONFIG_FILE_NAME;
	$thirdpartytools_config_file = "$base_work_dir/" . THIRDPARTYTOOLS_CONFIG_FILE_NAME;
	$hpcjob_config_file = "$base_work_dir/" . HPCJOB_CONFIG_FILE_NAME;
	$default_project_config_file = "$base_work_dir/" . DEFAULT_PROJECT_CONFIG_FILE_NAME;
	
}


sub init_project_dirs_and_files
{

	my $project = pop;	

	$project_data_dir = "$projects_data_dir/$project";
	$project_work_dir = "$projects_work_dir/$project";

	$project_config_file = "$project_work_dir/" . PROJECT_CONFIG_FILE_NAME;

	$starting_cluster_data_dir = "$project_data_dir/starting_clusters";
	$clustering_output_data_dir = "$project_data_dir/clustering_output";

	$temp_data_dir = "$project_data_dir/temp";
	
	$superfamilies_list_file = "$project_work_dir/" . PROJECT_SUPERFAMILIES_LIST_FILE_NAME;
	$superfamilies_size_file = "$project_data_dir/" . PROJECT_SUPERFAMILIES_SIZE_FILE_NAME;
	
	$system_call_stderr_file = "$project_work_dir/system_calls.errors";
	
}


sub load_project_settings
{

	# the project specific project config file
	load_settings($project_config_file, 1); 

	$persf_seq2ukb_dataset .= "/" . PERSF;
	$persf_seq2go_dataset .= "/" . PERSF;

}


sub check_args
{

	my ($args_ref, $num_args, $usage) = @_;
	
	if (@{$args_ref} < $num_args)
		{
		print "usage: $usage\n";
		exit;
		}
		
}


sub check_opt_args
{

	my ($args_ref, $arg_num, $undef_val) = @_;
	
	my $val = $undef_val;
	
	if (@{$args_ref} >= $arg_num)
		{ $val = ${$args_ref}[$arg_num - 1]; chomp $val; }	
	
	return $val;

}


sub disk_space_ok
{

	my ($dir, $min_free_blocks, $max_percent_usage) = @_;

	# nothing to do
	if ($min_free_blocks + $max_percent_usage == 0) { return 1; }

	my $cmd = SYSTEM_CALL_DF;
	my @output = `$cmd $dir`; 
	
	@output = split " ", $output[+SYSTEM_CALL_DF_LINE_TO_CHECK];  

	#DEBUG make col nums parameters
	my ($blocks_total, $blocks_used, $blocks_avail) = @output[1..3];

	if ($blocks_avail < $min_free_blocks) { return 0; }

	my $quota_percent_used = ($blocks_used/($blocks_used+$blocks_avail)) * 100; 
	
	# nothing else to do
	if ($max_percent_usage == 0) { return 1; }
	
	if ($quota_percent_used > $max_percent_usage) { return 0; }

	#$quota_percent_used = sprintf "%02.f", $quota_percent_used;
	#$blocks_avail = sprintf "%02.f", $blocks_avail/1000000;
	#print "$quota_percent_used $blocks_avail\n";
	
	return 1;	
	
}


#DEBUGxxx should check quotas on specific drives (where we use dirs)?
sub disk_quota_ok
{

	my ($min_free_blocks, $max_percent_usage) = @_;
	
	# nothing to do
	if ($min_free_blocks + $max_percent_usage == 0) { return 1; }
	
	my $cmd = SYSTEM_CALL_QUOTA;
	my @output = `$cmd`; 
	
	@output = split " ", $output[+SYSTEM_CALL_QUOTA_LINE_TO_CHECK];  

	#DEBUG make col nums parameters
	my ($blocks_used, $blocks_total) = @output[0,2];

	# no quota limit set
	if ($blocks_total == 0) { return 1; }
	
	my $blocks_avail = $blocks_total - $blocks_used;

	if ($blocks_avail < $min_free_blocks) { return 0; }

	my $quota_percent_used = ($blocks_used/$blocks_total) * 100; 
	
	# nothing else to do
	if ($max_percent_usage == 0) { return 1; }
	
	if ($quota_percent_used > $max_percent_usage) { return 0; }

	return 1;
	
}


# several safe_??? routines follow, these can be used when doing NFS and other error-prone file I/O
sub safe_sys_call
{

	my ($call, $call_type) = @_;

	$call .= " 2>$system_call_stderr_file";

	my $exit_code = 1;

	while (1)

		{ 

		$exit_code = system($call); 

		if ($exit_code == 0) { last; }

		else
		
			{ 
			print "ERROR $exit_code in " . $call_type . "! - keep trying...\n"; 
			sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY); 
			}

		}

}


sub safe_copy
{

	my ($source, $dest) = @_;

	while (! copy($source, $dest))

		{
		
		print "ERROR copying $source to $dest ($!) - keep trying...\n"; sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY);
			
		}

	return 1;

}


sub safe_move
{

	my ($source, $dest) = @_;

	while (! move($source, $dest))

		{
		
		print "ERROR moving $source to $dest ($!) - keep trying...\n"; sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY);
			
		}

	return 1;

}


sub safe_open
{

	my $file_mode_and_name = shift;
	my $FH;

	while (! open $FH, $file_mode_and_name) 
		{ 
		print "ERROR opening $file_mode_and_name ($!) - keep trying\n"; 
		sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY); 
		}; 

	return $FH;

}


sub safe_open_dir
{

	my $dir_name = shift;
	my $DH;

	while (! opendir $DH, $dir_name) 
		{ 
		print "ERROR opening $dir_name ($!) - keep trying\n"; 
		sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY); 
		}; 

	return $DH;
	
}


sub safe_glob
{

	my $glob = shift;
	my @globbed;

	while (1) 
		
		{ 
		
		@globbed = bsd_glob($glob, GLOB_ERR); 
		if (! GLOB_ERROR) { last; } 
	
		print "ERROR globbing $glob ($!) - keep trying\n"; 
		sleep(SYSTEM_CALL_SLEEP_SECS_BEFORE_RETRY); 
		
		}

	return \@globbed;

}


sub get_cur_dir
{

	my $cur_dir = `pwd`;
	chomp $cur_dir;
	return $cur_dir;

}	
 
 
sub strip_path_and_extension
{

	my $file_name = shift;

	$file_name =~ s{.*/}{};      # removes path  
	$file_name =~ s{\.[^.]+$}{}; # removes extension
	
	return $file_name;

}


sub strip_path
{

	my $file_name = shift;

	$file_name =~ s{.*/}{};      # removes path  
	
	return $file_name;

}


sub glob_files_without_path_and_extension
{

	my ($dir, $ext) = @_;
	
	my @files = @{safe_glob("$dir/*.$ext")};
	my @cols;
	
	foreach (@files) { $_ = strip_path_and_extension($_, $ext); }

	return \@files;

}


sub new_dir_if_nexists
{
	my $dir = shift;
	if (! -d $dir) { mkpath($dir); return 1; } else { return 0; }
}


sub new_or_clear_dir
{
	my $dir = shift;	
	if (! -d $dir) { new_dir_if_nexists($dir); }
	else { unlink(<$dir/*>); }
}


sub rm_dir_if_exists
{
	my $dir = shift;	
	if (-d $dir) { unlink(<$dir/*>); rmtree($dir); return 1; } else { return 0; }
}


#DEBUG move to fasta.pm
#NOTE this does not remove a leading ">"
# this gets rid of coordinates and any other information following one of the 
# separator characters in a FASTA sequence header
sub trunc_seq_header
{
	my $faa_header = shift;
	my @cols = split SEQ_HEADER_CORE_SEPARATOR, $faa_header;
	@cols = split SEQ_HEADER_ID_SEPARATOR, $cols[0];
	return $cols[0];
}


#DEBUG move to fasta.pm
#NOTE this does not remove a leading ">"
# this gets rid of coordinates and any other information following one of the 
# separator characters in a FASTA sequence header
sub split_seq_header
{
	my $faa_header = shift;
	my @cols = split SEQ_HEADER_CORE_SEPARATOR, $faa_header;
	@cols = split SEQ_HEADER_ID_SEPARATOR, $cols[0];
	return \@cols;
}


sub log10
{
       my $n = shift;
	   #DEBUG for our purposes!
       my $x = log($n) / log(10);
	   if ($x == 0) { $x = 1; }
	   return $x;
}


#DEBUG change all calls to this sub to use intersection() instead?
# @list2 must be larger or have the same size as @list1
sub is_subset
{

	my $ref = shift;
	my @list1 = @{$ref};
	$ref = shift;
	my %list2 = map { $_ => 0 } @{$ref};
	
	my $is_subset = 1;
	foreach (@list1) { if (! exists $list2{$_}) { $is_subset = 0; last; } }
	
	return $is_subset;
	
}


# @list2 must be larger or have the same size as @list1
sub intersection
{

	my ($l1ref, $l2ref) = @_;
	my @list1 = @{$l1ref};
	my %list2 = map { $_ => 0 } @{$l2ref};

	my @intersection = grep { exists $list2{$_} } @list1;
	
	return \@intersection;
	
}


#DEBUG this and sorted_union() could be merged into one
# returns any terms in $list1 which are not found in $list2
sub exclusive
{

	my ($l1ref, $l2ref) = @_;
	my @list1 = @{$l1ref}; #split $term_sep, $list1;
	my @list2 = @{$l2ref}; #split $term_sep, $list2;
	my @exclusive_list = ();

	foreach my $term(@list1) { if (! grep {$_ eq $term} @list2) { push @exclusive_list, $term; } }

	return \@exclusive_list;

}


sub sorted_union
{
	
	my ($l1ref, $l2ref) = @_;
	my @list1 = @{$l1ref}; #split $term_sep, $list1;
	my @list2 = @{$l2ref}; #split $term_sep, $list2;
	my %union;

	foreach (@list1, @list2) { $union{$_} = 1; }

	my @union = sort keys %union;
	return \@union;

}


sub remove_file_lines_before_match
{
	
	my ($file, $pattern) = @_;

	open my $OLD, "<$file";
	open my $NEW, ">$file.tmp";
	my $i = 0;
	while (<$OLD>) { if (m/$pattern/) { print $NEW $_; last; } $i++; }
	while (<$OLD>) { print $NEW $_; }
	close $NEW;
	close $OLD;
	#print "$i lines removed\n";
	system(SYSTEM_CALL_MV . " -f $file.tmp $file");

}


sub write_list
{

	my ($list_ref, $file_name) = @_;
	my @list = @{$list_ref};

	open my $F, ">$file_name";
	foreach (@list) { print $F "$_\n"; }
	close $F;

}


sub load_list
{

	my $file_name = shift;

	open my $F, "<$file_name";
	my @list = <$F>;
	close $F;
	chomp @list;

	return \@list;

}


sub load_list_nth_col
{

	my ($file_name, $col, $col_separator) = @_;

	my %hash = ();
	my (@list, @cols); 

	open my $F, "<$file_name";
	#DEBUG make both separators the same at one point, namely tab!
	while (<$F>) { chomp; @cols = split $col_separator, $_; push @list, $cols[$col]; }
	close $F;

	return \@list;

}


sub write_hash
{

	my ($hash_ref, $file_name, $col_separator) = @_;

	my %hash = %{$hash_ref};
		
	open my $F, ">$file_name";
	foreach (keys %hash) { print $F "$_" . $col_separator .  "$hash{$_}\n"; }
	close $F;

}


# key can be anything, values must be scalars (sorting)
sub write_value_sorted_hash
{

	my ($hash_ref, $file_name, $col_separator) = @_;

	my %hash = %{$hash_ref};
	my @keys_sorted_by_val = sort { $hash{$a} <=> $hash{$b} } keys %hash;
		
	open my $F, ">$file_name";
	foreach (@keys_sorted_by_val) { print $F "$_" . $col_separator .  "$hash{$_}\n"; }
	close $F;

}


sub write_hash_with_list_value_dif_separators
{

	my ($hash_ref, $file_name, $key_col_separator, $list_col_separator) = @_;

	my %hash = %{$hash_ref};
	my $list_string;

	open my $F, ">$file_name";
	#DEBUG make both separators the same at one point, namely tab!
	foreach (sort keys %hash) 
		{
		$list_string = join $list_col_separator, @{$hash{$_}};
		print $F $_ . $key_col_separator . $list_string . "\n"; 
		} 
	close $F;

}


sub write_hash_with_hash_value_dif_separators
{

        my ($hash_ref, $file_name, $key_col_separator, $list_col_separator) = @_;

        my %hash = %{$hash_ref};
        my $list_string;

        open my $F, ">$file_name";
        #DEBUG make both separators the same at one point, namely tab!
        foreach (sort keys %hash)
                {
                $list_string = join $list_col_separator, keys %{$hash{$_}};
                print $F $_ . $key_col_separator . $list_string . "\n";
                }
        close $F;

}


sub load_hash_with_list_value
{

	my ($file_name, $col_separator) = @_;

	if (! $col_separator) { $col_separator = DRCS; }
	
	my %hash = ();
	my @cols; 

	open my $F, "<$file_name";
	#DEBUG make both separators the same at one point, namely tab!
	while (<$F>) 
		{ chomp; @cols = split $col_separator, $_; $hash{$cols[0]} = [@cols[1..@cols - 1]]; }
	close $F;

	return \%hash;

}


sub load_hash_with_scalar_value_cols
{

	my ($file_name, $col_separator, $key_col, $val_col) = @_;

	my %hash = ();
	my @cols; 

	open my $F, "<$file_name";
	while (<$F>) 
		{ chomp; @cols = split $col_separator, $_; $hash{$cols[$key_col]} = $cols[$val_col]; }
	close $F;

	return \%hash;

}


sub load_hash_with_scalar_value
{

	my ($file_name, $col_separator) = @_;
	
	if (! $col_separator) { $col_separator = DRCS; }

	return load_hash_with_scalar_value_cols($file_name, $col_separator, 0, 1);

}


sub load_hash_with_scalar_value_filtered
{

	my ($file_name, $col_separator, $key_col, $val_col, $filter_col, $list_ref) = @_;

	my %hash = ();
	my @cols; 
	
	my %filter_set = map { $_ => 1 } @{$list_ref};
	
	open my $F, "<$file_name";
	while (<$F>) 
		{ 
		chomp; @cols = split $col_separator, $_; 
		#DEBUG can also make a not exists filter in the same way
		if (exists $filter_set{$cols[$filter_col]})
			{		
			$hash{$cols[$key_col]} = $cols[$val_col]; 
			}		
		}
	close $F;

	return \%hash;

}


sub load_hash_with_list_value_dif_separators
{

	my ($file_name, $key_col_separator, $list_col_separator) = @_;

	my %hash = ();
	my @cols; 
	
	#DEBUG this helps when, e.g., a GO root term does not have a parent
	no warnings 'uninitialized';
	
	open my $F, "<$file_name";
	#DEBUG make both separators the same at one point, namely tab!
	while (<$F>) { chomp; @cols = split $key_col_separator, $_; $hash{$cols[0]} = [split $list_col_separator, $cols[1]]; }
	close $F;

	return \%hash;

}


#DEBUG could use Perl functions like sub below instead
sub get_date
{

	my $cmd = SYSTEM_CALL_DATE;
	my $d = `$cmd`; chomp $d;
	return $d;

}


sub get_date_stamp
{

	my ($year, $month, $day) = (localtime(time))[5,4,3];
	#my $date_stamp = sprintf ("%04d-%02d-%02d", $year+1900, $month+1, $day);
	my $date_stamp = sprintf ("%02d%02d%04d", $day, $month+1, $year+1900);
	
	return $date_stamp;
	
}


sub get_user_yes_no
{

	my $question = shift;

	print $question . " (y/n)\n";

	my $choice = "";
	while (! $choice =~ /^[y|n]$/)
		{
		print "your choice: ";
		$choice = lc(<>);
		chomp $choice;
		}

	return ($choice eq "y");
		
}

#EOF
1;
