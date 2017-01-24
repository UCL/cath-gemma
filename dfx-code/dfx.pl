#!/usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

#NOTE could replace nohup by Perl forking
#TODO the problem of regexps being constants or not (see DEBUG comments)

use strict;
use warnings;

use FindBin qw ($Bin); use lib "$Bin/modules";
use common;
use prepare;
#DEBUG the 'use if' pragma and eval doesn't seem to work...
#DEBUG for now we use both the local/hpcpart modules
use localpart;
use hpcpart;
use annotations;

#DEBUG this way of switch-ing is deprecated in Perl6
use Switch;

my %parameters = (

	"install" => "
	install\n", 
	
	"prepare" => "	
	prepare
			ukbdata
			annodata
			idmapping
			seq2ukb
			seq2anno\n",

	"new" => "
	new
			project		\$project
			mapping		\$project	\$mapping\n",

	"delete" => "
	delete	
			runstep		\$project	\$runstep
			mapping		\$project	\$mapping
			project		\$project\n",
	
	"check" => "
	check\n",
	
	"run" => "
	run 						[ appending 'usesfs:sflistfile' works for most]
			\$project						
					precluster	
							
					tohpc
					cluster		
					tolocal
						
					identfams	
					namefams			
					annofams	
					modelfams						
					genthresh				
						
					[ nralnfams ]
					[ bmarkfams ]
					
					[ linkfamsets	\$famset_1 \$famset_2 ]

					mapassign	\$mapping
					mapassign_go	\$mapping
					mappool		\$mapping
					
					[ mapalign	\$mapping ]
					[ mapnraln	\$mapping ]
					
					map+map		\$new_mapping \$from_m1 \$from_m2
					map+seed	\$new_mapping \$from_mapping\n"
			
);

my $usage = $parameters{"install"} . $parameters{"prepare"} . $parameters{"new"} .
			$parameters{"delete"} . $parameters{"check"} . $parameters{"run"} . "\n";
	
common::check_args(\@ARGV, 1, "\n$usage");

common::load_settings(common::PIPELINE_CONFIG_FILE_NAME, 1); 
init();


sub init
{

	common::check_host();

	if ($local_run) 
		{
		warn "Running locally"; 
		localpart::init_local_dirs_and_files("none", "none");	
		} 
	else 
		{ 
		warn "Running on HPC";
		hpcpart::init_hpc_dirs_and_files("none", "none");	
		}

}

my ($project, $mapping, $entity, $command, $superfamily, @cols);

#DEBUGxxx don't allow for non-manual deletion of clustering data on HPC system for now
#DEBUGxxx same for any mapping related data
my @deletable_project_runsteps = 
qw (precluster identfams namefams annofams modelfams genthresh linkfamsets);

#DEBUG move to common.pm
my $batch_processing_script = "$batch_scripts_dir/batch_process_superfams.pl";
my $batch_max_instances_cheap = 100;
my $batch_max_instances_expensive = 100;

#DEBUG move to common.pm
my $hpc_ssh_logon_cmd = "ssh $hpc_user_name\@$hpc_ssh_target_node";
my $local_ssh_logon_cmd = "ssh $local_user_name\@$local_ssh_target_node";
my $ssh_errors_file = "$base_work_dir/ssh.log";

#DEBUGxxx make a cmd line arg
my $overwrite_mode = "yes";

										 
sub exit_if_not_local
{
	if (! $local_run)
		{ die "This can only be done on the local system!\n"; }
}	


sub exit_if_not_hpc
{
	if ($local_run)
		{ die "This can only be done on the HPC system!\n"; }
}


#DEBUG move following two to SSH specific module
sub ssh_mkdirs
{

	my ($ref, $ssh_logon_cmd) = @_;
	my @list = @{$ref};
	my $cmd = SYSTEM_CALL_MKDIR . " " . join "; mkdir ", @list;

	#DEBUG should do some checks if stuff exists here first
	system("$ssh_logon_cmd -C '$cmd' 2>>$ssh_errors_file"); 
	
}


sub ssh_copy_tarred
{

	my ($ref, $ssh_logon_cmd, $base_target_dir) = @_;
	my @list = @{$ref};
	my $cmd = SYSTEM_CALL_TAR . " -cf - @list | $ssh_logon_cmd -C '" . 
			  SYSTEM_CALL_CD . " $base_target_dir; " . SYSTEM_CALL_TAR . " -xf -'";

	#DEBUG
	#print "$cmd\n";
			  
	system("$cmd 2>>$ssh_errors_file");
	
}

		
# prior to this, the DFX archive must be unpacked to a certain
# directory and the pipeline config file must be customised
sub install
{
				
	#localpart::init_local_dirs_and_files("none", "none");
	
	my $cur_dir = common::get_cur_dir();
		
	if ($cur_dir ne $base_work_dir) 
		{ die "ERROR: DFX can only be installed from $base_work_dir\n"; }
	
	if (! common::new_dir_if_nexists($projects_data_dir))
		
		{ 
		
		print "WARNING: DFX seems to be installed on the local system already! (remove first?)\n"; 
		
		}
	
	else
	
		{
	
		print "installing on the local system...\n";
			
		common::new_dir_if_nexists($shared_data_dir);

		#DEBUG could be made part of the DFX archive
		common::new_dir_if_nexists($projects_work_dir);
		
		}

	print "installing/updating on the HPC system...\n";
	
	print "NOTE make sure that SSH and TAR work on the local and HPC systems.\n";
	print "NOTE enter your user password as requested by SSH below!\n";
	#print "NOTE make sure the DFX directories do not already exist on the HPC system.\n";
	
	#DEBUG now avoided through output redirection in ssh_... subs
	#print "To avoid seeing error messages add this line to the .bashrc on the HPC system:\n";
	#print "[ -z "$PS1" ] \&\& return\n";
				
	# pretend we're on the HPC system, to get the target paths correct
	$base_work_dir = $hpc_base_work_dir; $base_data_dir = $hpc_base_data_dir;		
	common::init_generic_dirs_and_files();	

	print "making directories on $hpc_ssh_target_node...\n";
	#DEBUG remove $projects_work_dir in case; see above
	my @list = ($base_work_dir, $projects_work_dir, $base_data_dir, $projects_data_dir);
	ssh_mkdirs(\@list, $hpc_ssh_logon_cmd);

	print "copying the relevant parts of DFX to $hpc_ssh_target_node...\n";
	my @config_files = (common::PIPELINE_CONFIG_FILE_NAME, 
						common::THIRDPARTYTOOLS_CONFIG_FILE_NAME,
						common::CLUSTERING_CONFIG_FILE_NAME,
						common::HPCJOB_CONFIG_FILE_NAME);
	#DEBUG make all those constants in common.pm
	@list = (@config_files, qw ( hpc_scripts/ batch_scripts/ modules/ tools/compass* tools/mafft* dfx.pl ));
	
	ssh_copy_tarred(\@list, $hpc_ssh_logon_cmd, $base_work_dir);
	
	#DEBUGxxx
	print "NOTE now prepare sequence and annotation data, before creating projects!\n";

}


sub to_hpc
{

	my $original_dir = common::get_cur_dir();
	my $local_projects_work_dir = $projects_work_dir;	
	my $local_project_data_dir = $project_data_dir;
	my $local_project_config_file = $project_config_file;
	
	my $local_superfamilies_size_file = $superfamilies_size_file;
	
	my @list;
	# pretend we're on the HPC system, to get the target paths right
	$base_work_dir = $hpc_base_work_dir; $base_data_dir = $hpc_base_data_dir;		
	common::init_generic_dirs_and_files();	
	common::init_project_dirs_and_files($project);
	#common::load_project_settings($project);

	#print "$project_data_dir, $projects_work_dir\n"; exit;

#=cut
	print "NOTE enter your user password as requested by SSH below!\n";

	print "making directories on $hpc_ssh_target_node...\n";
	#DEBUG remove $projects_work_dir in case; see above
	@list = ($project_data_dir);
	ssh_mkdirs(\@list, $hpc_ssh_logon_cmd);

	chdir $local_projects_work_dir;
	
	if (-e $local_project_config_file)
		{
		print "copying the project configuration to $hpc_ssh_target_node...\n";
		@list = ("$project/" . common::PROJECT_CONFIG_FILE_NAME );
		push @list, "$project/" . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME;
		ssh_copy_tarred(\@list, $hpc_ssh_logon_cmd, $projects_work_dir);
		}
#=cut
		
	chdir $local_project_data_dir;
		
	#DEBUG make constants in common.pm
	print "copying the starting clusters to $hpc_ssh_target_node...\n";
	@list = qw ( starting_clusters/ );
	push @list, common::PROJECT_SUPERFAMILIES_SIZE_FILE_NAME;
	ssh_copy_tarred(\@list, $hpc_ssh_logon_cmd, $project_data_dir);

	chdir $original_dir;
	
}


sub to_local
{

	my $original_dir = common::get_cur_dir();
	my $hpc_projects_work_dir = $projects_work_dir;	
	my $hpc_project_data_dir = $project_data_dir;
	
	my @list;
	
	# pretend we're on the local system, to get the target paths right
	$base_work_dir = $local_base_work_dir; $base_data_dir = $local_base_data_dir;		
	common::init_generic_dirs_and_files();	
	common::init_project_dirs_and_files($project);
	#common::load_project_settings($project);

	print "NOTE enter your user password as requested by SSH below!\n";

	print "making directories on $local_ssh_target_node...\n";
	@list = ($clustering_output_data_dir);
	ssh_mkdirs(\@list, $local_ssh_logon_cmd);

	chdir $hpc_projects_work_dir;
	
	#DEBUG make constants in common.pm
	if (-d "$project/batch_cluster/")
		{
		print "copying the clustering protocols to $local_ssh_target_node...\n";
		#DEBUG make constants in common.pm
		@list = ("$project/batch_cluster/");
		ssh_copy_tarred(\@list, $local_ssh_logon_cmd, $projects_work_dir);
		}
	
	chdir $hpc_project_data_dir;
	
	print "copying the clustering trace data to $local_ssh_target_node...\n";
	#DEBUG make constants in common.pm
	@list = qw ( clustering_output/ );
	ssh_copy_tarred(\@list, $local_ssh_logon_cmd, $project_data_dir);

	chdir $original_dir;

}


sub new_project
{

	$project_data_dir = "$projects_data_dir/$project";
	if (-d $project_data_dir) 
		{ print "ERROR: $project_data_dir already exists! (delete first?)\n"; exit; }

	$project_work_dir = "$projects_work_dir/$project";
	if (-d $project_work_dir) 
		{ print "ERROR: $project_work_dir already exists! (delete first?)\n"; exit; }

	#DEBUG if we one day separate name, taxon id and function annotation this
	#DEBUG has to change; e.g., we would look for "anno_to_goa" here, then select
	#DEBUG the other annotation (name, taxon, ...) datasets in a similar way;
	#DEBUG e.g., we would look for "anno_to_names_uniprot", "anno_to_taxid_uniprot"

	$persf_seq2go_dataset = 
	prepare::select_dataset("GO-annotated sequence", 
						    $used_shared_data_dir, ANNO_TO . "_" . common::GO_DATA_DIR_PREFIX, "");
	localpart::verify_project_input_datasets($persf_seq2go_dataset);
		
	# enforce the chosen sequence dataset
	my $signature = $persf_seq2go_dataset;
	my $regex = ANNO_TO . ".\*\$";
	$signature =~ s/$regex//;
		
	$persf_seq2ukb_dataset = 
	prepare::select_dataset("UniProt-annotated sequence", 
						    $used_shared_data_dir, $signature . ANNO_TO . "_" . common::UNIPROT_DATA_DIR_PREFIX, "");
	localpart::verify_project_input_datasets($persf_seq2ukb_dataset);
	
	$go_ontology_hash_file_set = 
	prepare::select_dataset("GO term definitions and hierarchy", 
							$used_shared_data_dir, 
							$go_ontology_oboxml_file, "");
	localpart::verify_project_input_datasets($go_ontology_hash_file_set);

	$ukb_taxonomy_hash_file_set = 
	prepare::select_dataset("UniProt taxonomy",
							$used_shared_data_dir, common::UNIPROT_TAXONOMY_FILE_NAME, 
							common::UNIPROT_TAXONOMY_FILE_NAME);

	localpart::verify_project_input_datasets($ukb_taxonomy_hash_file_set);
	
	common::new_dir_if_nexists($project_data_dir);	
	#NOTE we create all other subdirs on the go, with each step of the pipeline 
	#NOTE being executed, so that progress is reflected in the emerging directory 
	#NOTE structure
	
	#DEBUGxxx think that's not required
	#common::new_or_clear_dir($temp_data_dir);

	$persf_seq_dataset = 
	localpart::persf_seq2anno_dataset_to_persf_seq_dataset($persf_seq2go_dataset);
	#DEBUGxxx the ".." is not ideal here, try to get this dir directly
	my $superfamilies_list_file_template = "$persf_seq_dataset/../" . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME;
	my $superfamilies_size_file_template = "$persf_seq_dataset/../" . common::PROJECT_SUPERFAMILIES_SIZE_FILE_NAME;

	common::init_project_dirs_and_files($project);
	common::new_dir_if_nexists($project_work_dir);	
	#DEBUGxxx
	system(SYSTEM_CALL_COPY . " $superfamilies_list_file_template $superfamilies_list_file");
	system(SYSTEM_CALL_COPY . " $superfamilies_size_file_template $superfamilies_size_file");
	
	#DEBUGxxx in case we wanted a template before adding/editing things below
	#system(SYSTEM_CALL_COPY . " $default_project_config_file $project_config_file");

	open my $PCF, ">$project_config_file";
	#DEBUGxxx make this a parameter
	#DEBUG it's also a bit inconsistent to have all *.pl scripts have a space
	#DEBUG following the #! but not the *.config files
	print $PCF "\#!/usr/bin/perl -w\n";
	print $PCF "\n";
	print $PCF "\$persf_seq2ukb_dataset = \"$persf_seq2ukb_dataset\"\;\n";
	print $PCF "\$persf_seq2go_dataset = \"$persf_seq2go_dataset\"\;\n";
	print $PCF "\$go_ontology_hash_file_set = \"$go_ontology_hash_file_set\"\;\n";
	print $PCF "\$ukb_taxonomy_hash_file_set = \"$ukb_taxonomy_hash_file_set\"\;\n";
	print $PCF "\n";
	print $PCF "\$family_set = \"funfams\"\;\n";
	close $PCF;

	#print "NOTE customise $project_config_file to complete project initialisation!\n";
	print "NOTE you can edit " . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME . " in $project_work_dir to process only a subset of the superfamilies.\n";

	#NOTE we do this for verification: if it fails, something went wrong above
	common::init_project_dirs_and_files($project);
	common::load_project_settings($project);
	localpart::verify_all_project_input_datasets();
		
}


sub delete_project
{

	#DEBUG put similar stuff to delete_mappings() here if below comment becomes
	#DEBUG relevant
	#init_local_or_hpc();
	
	if (! -d $project_data_dir) { die "ERROR: project $project not found!\n"; }

	common::rm_dir_if_exists($project_data_dir);
	
	common::rm_dir_if_exists($project_work_dir);
	
	#DEBUG could automate this step but as the clusterig data is so 'precious'
	#DEBUG this is thought to make accidential deletion improbable
	if ($local_run)
		{ print "NOTE execute the same command on the HPC system to complete project deletion!\n"; }
	
}


sub new_mapping
{
		
	localpart::init_mapping_dirs_and_files($mapping, "none");
		
	if (-d $mapping_data_dir)
		{ die "ERROR: mapping $mapping already exists!\n"; }	

	common::new_dir_if_nexists($mappings_data_dir);
	
	common::new_dir_if_nexists($mapping_data_dir);
	
	if ($mapping eq "self")
		{
				
		$persf_seq_dataset = 
		localpart::persf_seq2anno_dataset_to_persf_seq_dataset($persf_seq2go_dataset);
		
		# create a symbolic link to avoid copying the whole FASTA data
		if (system(SYSTEM_CALL_LNS . " $persf_seq_dataset $mapping_target_mfasta_data_dir") != 0)
			{
			die "ERROR: cannot create symbolic link $mapping_target_mfasta_data_dir to $persf_seq_dataset\n";
			}
		print "NOTE the $mapping mapping is ready for scanning! (mapscan)\n";
		}
	else
		{
		common::new_dir_if_nexists($mapping_target_mfasta_data_dir);
		print "NOTE put domain FASTA files into $mapping_target_mfasta_data_dir to prepare the mapping!\n";
		}
		
}


sub delete_mapping
{

	localpart::init_mapping_dirs_and_files($mapping, "none");
	
	if (! -d $mapping_data_dir)
		{ die "ERROR: mapping $mapping not found!\n"; }
	
	common::rm_dir_if_exists($mapping_data_dir);
	
	if ($local_run)
		{ print "NOTE any corresponding batch run data in $project_data_dir can now be deleted!\n"; }
	
}


sub combine_two_mappings
{

	my ($map1, $map2) = @_;

	my $dest_mfasta_data_dir = $mapping_mfasta_data_dir;
	my $dest_seqids_data_dir = $mapping_seqids_data_dir;

	localpart::init_mapping_dirs_and_files($map1, "none");
	my $map1_mfasta_data_dir = $mapping_mfasta_data_dir;
	if (! -d $map1_mfasta_data_dir) 
		{ print "pool $map1 sequences first!\n"; exit; }
	my $map1_seqids_data_dir = $mapping_seqids_data_dir;

	localpart::init_mapping_dirs_and_files($map2, "none");
	my $map2_mfasta_data_dir = $mapping_mfasta_data_dir;
	if (! -d $map2_mfasta_data_dir) 
		{ print "pool $map2 sequences first!\n"; exit; }
	my $map2_seqids_data_dir = $mapping_seqids_data_dir;

	#DEBUG
	#$superfamilies_list_file = "superfamilies.one";

	my @superfamilies = @{common::load_list($superfamilies_list_file)};

	common::new_dir_if_nexists($dest_mfasta_data_dir);
	#common::new_dir_if_nexists($dest_seqids_data_dir);

	foreach (@superfamilies)
		{
		if ((! -d "$map1_mfasta_data_dir/$_") && (! -d "$map2_mfasta_data_dir/$_")) { next; }
		print "$_\n";
		common::new_dir_if_nexists("$dest_mfasta_data_dir/$_");
		#DEBUG redirect
		system("$tools_dir/concat_same_name_files.sh $map1_mfasta_data_dir/$_ $map2_mfasta_data_dir/$_ $dest_mfasta_data_dir/$_ " . FAA . " >/dev/null");
		#common::new_dir_if_nexists("$dest_seqids_data_dir/$_");
		#system("$tools_dir/concat_same_name_files.sh $map1_seqids_data_dir/$_ $map2_seqids_data_dir/$_ $dest_seqids_data_dir/$_ seqids >/dev/null");
		}

}

	
sub combine_mapping_and_seed
{

	my ($source_mapping) = @_;

	my $new_map_mfasta_data_dir = $mapping_mfasta_data_dir;

	localpart::init_mapping_dirs_and_files($source_mapping, "none");
	if (! -d $mapping_mfasta_data_dir) 
		{ print "pool $source_mapping sequences first!\n"; exit; }

	my @superfamilies = @{common::load_list($superfamilies_list_file)};

	common::new_dir_if_nexists($new_map_mfasta_data_dir);

	foreach (@superfamilies)
		{
		if (! -d "$mapping_mfasta_data_dir/$_") { next; }
		print "$_\n";
		common::new_dir_if_nexists("$new_map_mfasta_data_dir/$_");
		system("$tools_dir/concat_same_name_files.sh $family_mfasta_data_dir/$_ $mapping_mfasta_data_dir/$_ $new_map_mfasta_data_dir/$_ " . FAA . " >/dev/null");
		}

}

	
sub batch_process
{

	#NOTE $task_name will be used to name a subdirectory in the work directory
	#NOTE of this project that is created for this particular batch run
	my ($script, $task_name, $max_instances) = @_;
	
	# any optional parameters must be comma-separated!
	my $optional_script_parameters = common::check_opt_args(\@_, 4, "none");

	#init_local_or_hpc();
	
	# check for further generic parameters 
	while (@ARGV)
		{
		my $optional_parameter = shift @ARGV;

		#DEBUG should make paras constants
		# do things or avoid doing things for a custom set of superfamilies
		if ($optional_parameter =~ /^(usesfs|omitsfs)\:(.*)/)
			{
			if ($1 eq "usesfs") 
				{
				$superfamilies_custom_list_file = $2; 
				last;
				}				
			#DEBUG for now just filter sf list file beforehand to omit superfamilies
			}
		}

	if (defined($superfamilies_custom_list_file))
		{
		$superfamilies_list_file = $superfamilies_custom_list_file;
		print "using: $superfamilies_list_file\n";
		}
		
	if (! -e $superfamilies_list_file) 
		{ die "superfamily list file $superfamilies_list_file not found!\n"; }
		
	my $batch_work_dir = "$project_work_dir/batch\_$task_name" . $family_set;
	
	if ($local_run)
		{
		# to be able to distribute local tasks between different machines 
		# (e.g., bsmcmp11, 21 and 23)
		$batch_work_dir = "$batch_work_dir/$host_name";
		}
	
	#DEBUG
	#if (-d $batch_work_dir)
	#	{ print "ERROR: $batch_work_dir already exists! (batch task already running?)\n"; exit; }
	
	my @flag_files = <"$batch_work_dir/*.running">;
	if (@flag_files)
		{
		print "ERROR: there exist running batch processes of the same type (according to flag files in $batch_work_dir)\n"; exit;
		}
	
	common::new_dir_if_nexists($batch_work_dir);
		
	my $batch_run_output_file = "$batch_work_dir/batch_run.output";
		
	#DEBUG impose no limits on superfamily size - this could all go to project config
	#DEBUG $additional_parameters is not used anymore
	my $cmd = SYSTEM_CALL_NOHUP . " $batch_processing_script $project $script $batch_work_dir $superfamilies_list_file $superfamilies_size_file 0 " . common::INFINITY . " " . common::INFINITY . " $max_instances $overwrite_mode $optional_script_parameters > $batch_run_output_file";
	#my $cmd = SYSTEM_CALL_NOHUP . " $batch_processing_script $project $script $batch_work_dir $superfamilies_list_file $superfamilies_size_file 0 " . common::INFINITY . " " . common::INFINITY . " $max_instances $overwrite_mode $optional_script_parameters > $batch_run_output_file &";
	warn "cmd: $cmd";
	system($cmd) == 0 or die "system $cmd failed: $?";
	
}


sub check_running_batch_processes
{

	#DEBUG whole sub is a quick and dirty hack, relying on the
	#DEBUG current tree structure of the projects/ folder
	my @output = `ls -1 projects/*/*/*/*.running 2>/dev/null`;
	my @x = @output;
	@output = `ls -1 projects/*/*/*.running 2>/dev/null`;
	push @x, @output;
	#print "@output\n";
	if (@x)
		{
		foreach (@x)
			{
			chomp;
			#print "$_";
			@cols = split /\//, $_;
			$_ =~ s/$cols[-1]//; chop;
			print `wc -l $_/*.done`;
			}
		}
	else
		{
		print "no running batch processes according to flag files (double-check with ps on the respective machines if in doubt!)\n"
		}
		
}


my $task = shift @ARGV;

if (exists $parameters{$task}) { $usage = "\n$parameters{$task}"; }
else { print "$usage"; exit; }
		
switch ($task) 
	
	{
	
	case "install" 
		
		{ 

		exit_if_not_local();
		
		install();
		
		}
	
	case "prepare" 
		
		{ 

		exit_if_not_local();
		
		common::check_args(\@ARGV, 1, "$usage");
		$command = shift @ARGV;

		common::load_settings($datasources_config_file, 1);
		
		#DEBUG all the following could be created on first need in prepare.pm
		common::new_dir_if_nexists($raw_shared_data_dir);
		common::new_dir_if_nexists($processed_shared_data_dir);
		common::new_dir_if_nexists($used_shared_data_dir);

		common::new_dir_if_nexists($idmappings_data_dir);
		
		# overwrite this, it's usually $project_data_dir/temp but here
		# we have no specific project assigned yet
		$ENV{"TMPDIR"} = $raw_shared_data_dir;

		# used for downloaded files below
		$common::date_stamp = common::get_date_stamp();
		#DEBUG for testing things over several days without cluttering the drives
		#$common::date_stamp = "05122012";
				
		switch ($command) 

			{
			
			case "ukbdata" { prepare::prepare_uniprot_kb_dataset(); }
			case "annodata" { prepare::prepare_go_and_uniprot_goa_dataset(); }
			case "idmapping" { prepare::prepare_idmapping_dataset(); }
			case "seq2ukb" { prepare::prepare_seq2ukb_dataset(); }
			case "seq2anno" { prepare::prepare_seq2anno_dataset(); }

			else { print $parameters{$task}; }
			
			}
		
		}
	
	case "new" 
	
		{ 
	
		exit_if_not_local();
	
		common::check_args(\@ARGV, 2, "$usage");
		$entity = shift @ARGV;
		$project = shift @ARGV;
		
		switch ($entity) 

			{
			
			case "project" { new_project(); }

			case "mapping" 
				
				{ 

				init_local_dirs_and_files($project, "none");
				#common::init_project_dirs_and_files($project);
				#common::load_project_settings($project);
				#localpart::verify_all_project_input_datasets();
				
				common::check_args(\@ARGV, 1, "$usage");
				$mapping = shift @ARGV;
			
				new_mapping(); 
				
				}
				
			else { print "$usage\n"; }
			
			}
		
		}
	
	case "delete" 
	
		{ 
		
		common::check_args(\@ARGV, 2, "$usage");
		$entity = shift @ARGV;
		$project = shift @ARGV;
		
		common::init_project_dirs_and_files($project);
		common::load_project_settings($project);
		localpart::verify_all_project_input_datasets();
		
		switch ($entity) 

			{
			
			case "project" 
			
				{ 
				
				delete_project(); 
								
				}

			case "mapping" 
				
				{ 
		
				exit_if_not_local();
		
				common::check_args(\@ARGV, 1, "$usage");
				$mapping = shift @ARGV;
			
				delete_mapping(); 
				
				}
				
			case "runstep"
			
				{
				
				#DEBUGxxx remove this if we allow to delete clustering data;
				#DEBUGxxx see @deletable_project_runsteps definition above
				exit_if_not_local();
				
				common::check_args(\@ARGV, 1, "$usage");
				# $command = runstep here, see below for equivalent use of $command
				$command = shift @ARGV;
				
				if (! grep { $_ eq $command } @deletable_project_runsteps)
					{
					print "\'$command\' is either not a recognised step OR the data " .
						  "produced in that step is so far only manually deletable.\n";
					exit;
					}

				my $batch_work_dir = "$project_work_dir/batch\_$command" . $family_set;
				if ($command eq "linkfamsets") { $batch_work_dir .= "\*"; }
				if (common::get_user_yes_no("do you really want to delete $batch_work_dir?"))
					{
					system("rm -rf $batch_work_dir");
					print "done.\n";
					print "please manually delete the appropriate sub-directory of ".
						  "$family_data_dir [automatic deletion will be implemented]\n"; 
					}
				else
					{ print "nothing has been deleted.\n"; exit; }
					
				}
				
			else { print "$usage\n"; }
			
			}
		
		}

	case "check"
	
		{
		
		check_running_batch_processes();
		
		}

	case "run" 
	
		{ 
		
		common::check_args(\@ARGV, 2, "$usage");
		$project = shift @ARGV;
		$command = shift @ARGV;

		#DEBUG check if command is a valid command at all here
		
		if (! grep { $_ eq $command } qw (cluster tolocal))
			{
			exit_if_not_local();
			localpart::init_local_dirs_and_files($project, "none");
			}
		else 
			{ 
			exit_if_not_hpc(); 
			hpcpart::init_hpc_dirs_and_files($project, "none");
			}

		#DEBUG is implicit in the above calls
		#common::load_project_settings($project);
		
		if (! -d $project_data_dir) 
			{ die "ERROR: project $project not found!\n"; }
		
		if ($command =~ /^map/)			
			{			
			
			common::check_args(\@ARGV, 1, "$usage");
			$mapping = shift @ARGV;
			
			localpart::init_mapping_dirs_and_files($mapping, "none");
			
			if (! -d $mapping_data_dir)
				{ die "ERROR: mapping $mapping not found!\n"; }			
			
			}
				
		switch ($command) 

			{
			
			case "precluster" 
					
				{	

				common::new_dir_if_nexists($starting_cluster_data_dir);
				common::new_dir_if_nexists($exc_starting_cluster_data_dir);
				common::new_dir_if_nexists($temp_data_dir);
				
				batch_process("wrapper_precluster.pl", $command, $batch_max_instances_cheap); 
							
				}
			
			# pure I/O, hence not distributed
			case "tohpc" 
			
				{ 

				if (! -d $starting_cluster_data_dir) 
					{ print "generate starting clusters first! (precluster)\n"; exit; }

				to_hpc(); 
				
				}
			
			case "cluster" 
			
				{ 
	
				if (! -d $starting_cluster_data_dir) 
					{ print "copy starting clusters first! (tohpc)\n"; exit; }
	
				common::new_dir_if_nexists($clustering_output_data_dir);
				#DEBUGxxx create when installing on HPC system?
				common::new_dir_if_nexists($temp_data_dir);
	
				batch_process("wrapper_cluster.pl", $command, $batch_max_instances_expensive); 
				
				}
			
			# pure I/O, hence not distributed
			case "tolocal" { to_local(); }
			
			case "identfams" 
			
				{ 
				
				if (! -d $clustering_output_data_dir) 
					{ print "cluster sequences first!\n"; exit; }
								
				common::new_dir_if_nexists($family_data_dir);
				
				common::new_dir_if_nexists($family_sizes_data_dir);
				common::new_dir_if_nexists($family_mfasta_data_dir);
				common::new_dir_if_nexists($family_trees_data_dir);
				common::new_dir_if_nexists($family_core_terms_data_dir);
				common::new_dir_if_nexists($family_term_counts_data_dir);
				common::new_dir_if_nexists($family_generic_sibling_cluster_data_dir);
				
				#common::new_dir_if_nexists($temp_data_dir);
	
				batch_process("identify_families.pl", $command, $batch_max_instances_expensive);
				
				}
				
			case "namefams" 
			
				{ 
				
				if (! -d $family_mfasta_data_dir) 
					{ print "identify families first!\n"; exit; }
					
				common::new_dir_if_nexists($family_names_data_dir);
	
				batch_process("name_families.pl", $command, $batch_max_instances_cheap); 
				
				}

			case "annofams" 
			
				{ 
				
				if (! -d $family_mfasta_data_dir) 
					{ print "identify families first!\n"; exit; }
					
				common::new_dir_if_nexists($family_anno_data_dir);
	
				batch_process("annotate_families.pl", $command, $batch_max_instances_cheap); 
				
				}
			
			case "modelfams" 
			
				{ 
				
				if (! -d $family_mfasta_data_dir) 
					{ print "identify families first!\n"; exit; }
					
				common::new_dir_if_nexists($family_alignments_data_dir);					
				#DEBUG we could use the temp folder for all models instead, as
				#DEBUG only the model libraries are being used eventually
				common::new_dir_if_nexists($family_models_data_dir);					
				common::new_dir_if_nexists($family_modlib_data_dir);
					
				batch_process("model_families.pl", $command, $batch_max_instances_expensive);
				
				}

			case "genthresh"
				
				{
				
				if (! -d $family_models_data_dir) 
					{ print "build models first!\n"; exit; }
				
				common::new_dir_if_nexists($family_modthresh_data_dir);
				
				batch_process("generate_family_thresholds.pl", $command, $batch_max_instances_expensive); 
				
				}
			
			case "nralnfams"

				{

				if (! -d $family_mfasta_data_dir)
					{ print "identify families first!\n"; exit; }

				common::new_dir_if_nexists($family_anno_only_mfasta_data_dir);
				common::new_dir_if_nexists($family_anno_only_nonred_mfasta_data_dir); 
				common::new_dir_if_nexists($family_anno_only_nonred_alignments_data_dir);
					
				batch_process("wrapper_anno_only_nonred_align.pl", $command, $batch_max_instances_expensive);

				}
				
			case "bmarkfams"
				
				{
				
				if (! -d $family_mfasta_data_dir)
					{ print "identify families first!\n"; exit; }
					
				common::new_dir_if_nexists($benchmark_data_dir);

				batch_process("benchmark_simple_score_families.pl", $command, $batch_max_instances_cheap);
				
				}
				
			#DEBUG undocumented
			case "bmpurevi"
				
				{
				
				if (! -d $family_mfasta_data_dir)
					{ print "identify families first!\n"; exit; }
					
				#DEBUGxxx
				$benchmark_data_dir .= "_purevi";
				common::new_dir_if_nexists($benchmark_data_dir);

				batch_process("benchmark_score_families.pl", $command, $batch_max_instances_cheap);
				
				}

			case "linkfamsets"

				{

				common::check_args(\@ARGV, 2, "$usage");
				my $famset1 = shift @ARGV;
				my $famset2 = shift @ARGV;

				#NOTE this order because we want $family_set to be set to
				#NOTE $famset1 afterwards, so the output goes to the right dir
				localpart::init_family_set_dirs_and_files($famset2);
				if (! -d $family_sizes_data_dir)
					{ print "family set '$famset2' not found or incomplete!\n"; exit; }
				localpart::init_family_set_dirs_and_files($famset1);
				if (! -d $family_sizes_data_dir)
					{ print "family set '$famset1' not found or incomplete!\n"; exit; }
					
				#NOTE a trick to make the following sub use an extended
				#NOTE name for the batch run dir
				$family_set .= "_to_$famset2";
					
				batch_process("link_two_family_sets.pl", $command, $batch_max_instances_cheap, "$famset1,$famset2");
	
				}
	
			#NOTE we could split the scan and assign steps
			case "mapassign"
			
				{
				
				if (! -d $mapping_data_dir) 
					{ print "create mapping first!\n"; exit; }
				
				common::new_dir_if_nexists($mapping_data_dir);
				common::new_dir_if_nexists($mapping_scan_data_dir);	
				common::new_dir_if_nexists($mapping_assignments_data_dir);

				batch_process("wrapper_mapping_scan_and_assign.pl", "$command\_$mapping", $batch_max_instances_expensive, $mapping); 
				
				}

			case "mapassign_go"
			
				{
				
				if (! -d $mapping_data_dir) 
					{ print "create mapping first!\n"; exit; }
				
				common::new_dir_if_nexists($mapping_data_dir);
				common::new_dir_if_nexists($mapping_scan_data_dir);	
				common::new_dir_if_nexists($mapping_assignments_data_dir);

				batch_process("wrapper_mapping_assign_to_goterms.pl", "$command\_$mapping", $batch_max_instances_expensive, $mapping); 
				
				}
				
			case "mappool"
			
				{
				
				if (! -d $mapping_assignments_data_dir) 
					{ print "scan and assign sequences first!\n"; exit; }
				
				common::new_dir_if_nexists($mapping_seqids_data_dir);
				common::new_dir_if_nexists($mapping_mfasta_data_dir);
				
				batch_process("wrapper_mapping_pool.pl", "$command\_$mapping", $batch_max_instances_expensive, $mapping); 
				
				}
			
			# pure I/O, hence not distributed
			case "map+map"
			
				{
		
				common::check_args(\@ARGV, 2, "$usage");
				my $map1 = shift @ARGV;
				my $map2 = shift @ARGV;

				#DEBUG create the new mapping automatically in case here
				
				combine_two_mappings($map1, $map2);
				
				#DEBUG could remove the empty target_mfasta_dir of 
				#DEBUG this combined mapping here, since it does not have 
				#DEBUG it's own mfasta data
					
				}
				
			# same here
			case "map+seed"
			
				{
				
				common::check_args(\@ARGV, 1, "$usage");
				my $mapping = shift @ARGV;
				
				#DEBUG create the new mapping automatically in case here

				combine_mapping_and_seed($mapping);
				
				#DEBUG could remove the empty target_mfasta_dir of 
				#DEBUG this combined mapping here, since it does not have 
				#DEBUG it's own mfasta data
								
				}
				
			#DEBUG could avoid the wrapper if we made the align a dir
			#DEBUG of mfastas script ($tools_dir/align_mfasta_files.sh)
			#DEBUG a Perl one; see also wrapper_mapping_align.pl
			case "mapalign"
			
				{

				if (! -d $mapping_mfasta_data_dir) 
					{ print "pool sequences into families first!\n"; exit; }

				common::new_dir_if_nexists($mapping_alignments_data_dir);

				batch_process("wrapper_mapping_align.pl", "$command\_$mapping", $batch_max_instances_expensive, $mapping);

				}
				
			case "mapnraln"
			
				{

				if (! -d $mapping_mfasta_data_dir) 
					{ print "pool sequences into families first!\n"; exit; }

				common::new_dir_if_nexists($mapping_nonred_mfasta_data_dir); 
				common::new_dir_if_nexists($mapping_nonred_alignments_data_dir);

				batch_process("wrapper_mapping_nonred_align.pl", "$command\_$mapping", $batch_max_instances_expensive, $mapping);

				}

			else { print "$usage\n"; }
			
			}		
		
		}
	
	}
