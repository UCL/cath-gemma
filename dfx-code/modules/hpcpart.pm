#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package hpcpart;

use strict;

use common;


# these path parameters are exported into the main namespace and set calling 
# init_hpc_dirs_and_files() from the main script
our @EXPORT = 

qw

(

	$superfamily_clustering_dir

);

our $VERSION = '1.00';
use base 'Exporter';

our 

(
	
	$superfamily_clustering_dir,
	
);


sub init_superfamily_dirs_and_files
{

	my $superfamily = shift;

	$starting_cluster_dir = "$starting_cluster_data_dir/$superfamily";
	#DEBUG this may change in the future; in specific, a 'clustering'
	#DEBUG subdir could be inserted between the two following;
	#DEBUG also make sure this ties in with dfx.pl calling cluster_sequences.pl
	$superfamily_clustering_dir = "$project_work_dir/$superfamily";

	#DEBUG may wanna resolve $superfamily_clustering_trace_file location mismatch 
	#DEBUG between local/HPC
	#DEBUG this is the storage (target) destination of this file once clustering has finished
	#DEBUG see wrapper_cluster.pm comment too
	#DEBUGxxx make 'trace' a constant, then refer to this both here
	#DEBUGxxx and in cluster_sequences.pl - see comment there too
	#$superfamily_clustering_trace_file = "$superfamily_clustering_dir/trace/merges.trace";
	$superfamily_clustering_trace_file = "$clustering_output_data_dir/$superfamily.trace";

}


sub init_hpc_dirs_and_files
{

	my ($project, $superfamily) = @_; 	

	# the generic config file (located automatically, provides $hpc_base_work_dir)
	common::load_settings(common::PIPELINE_CONFIG_FILE_NAME, 1);
	
	$base_work_dir = $hpc_base_work_dir;
	$base_data_dir = $hpc_base_data_dir;
	$scripts_dir = "$base_work_dir/hpc_scripts";
	common::init_generic_dirs_and_files();
	
	# mainly needed in HPC part
	common::load_settings($clustering_config_file, 1); 

	# defining paths to third-party tools and parameter settings 
	common::load_settings($thirdpartytools_config_file, 1);

	# the only config file specific to the HPC part of the pipeline
	common::load_settings($hpcjob_config_file, 1); 

	if ($project eq "none") { return; }

	# the project specific project config file
	common::init_project_dirs_and_files($project);
	common::load_project_settings($project);
		
	init_superfamily_dirs_and_files($superfamily)
		
}


#EOF
1;

