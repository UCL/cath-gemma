#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package localpart;

use strict;

use common;
use annotations;
use taxonomy;

#these path parameters are exported into the main namespace and are set 
# by calling init_local_dirs_and_files() from the main script
our @EXPORT = 

qw

(

	$exc_starting_cluster_data_dir
	$exc_starting_cluster_dir
		
	$family_data_dir
	$mappings_data_dir
	
	$mapping_data_dir

	$family_sizes_data_dir
	$family_core_terms_data_dir
	$family_term_counts_data_dir
	$family_anno_data_dir
	$family_trees_data_dir
	
	$family_names_data_dir
	$family_taxo_data_dir
	
	$family_mfasta_data_dir
	$family_alignments_data_dir
	$family_models_data_dir
	$family_modlib_data_dir	
	
	$family_generic_sibling_cluster_data_dir
	
	$family_modthresh_data_dir
		
	$family_anno_only_mfasta_data_dir
	$family_anno_only_nonred_mfasta_data_dir
	$family_anno_only_nonred_alignments_data_dir		
		
	$benchmark_data_dir

	$mapping_target_mfasta_data_dir
	$mapping_scan_data_dir
	$mapping_assignments_data_dir
	$mapping_assignments_go_data_dir
	
	$mapping_seqids_data_dir
	$mapping_mfasta_data_dir
	$mapping_alignments_data_dir

	$mapping_stats_data_dir
	$mapping_nonred_mfasta_data_dir
	$mapping_nonred_alignments_data_dir

	$family_term_counts_dir
	$family_anno_dir

	$family_mfasta_dir	
	$family_alignments_dir
	$family_models_dir

	$family_anno_only_mfasta_dir
	$family_anno_only_nonred_mfasta_dir
	$family_anno_only_nonred_alignments_dir
	
	$family_generic_sibling_cluster_dir

	$superfamily_anno_file
	
	$superfamily_name_file
	$superfamily_taxid_file
	$superfamily_exclude_file
	
	$superfamily_mfasta_file
		
	$unsupervised_clustering_flag_file

	$family_sizes_file
	
	$family_core_terms_file

	$json_family_tree_file
	$newick_family_tree_file
	
	$family_names_file
	$family_taxo_file
	
	$family_modlib_file
	
	$family_siblings_file
	
	$model_inc_threshold_file
	$model_exc_threshold_file

	$mapping_target_mfasta_file
	$mapping_scan_file
	$mapping_assignments_file
	$mapping_assignments_go_file

	$mapping_stats_file

	$mapping_seqids_dir
	$mapping_mfasta_dir
	$mapping_alignments_dir
	
	$mapping_nonred_mfasta_dir
	$mapping_nonred_alignments_dir

	$superfamily_libgen_errors_file
	
	$superfamily_benchmark_scores_file
	$superfamily_benchmark_performance_file
	
);

our $VERSION = '1.00';
use base 'Exporter';

our 

(

	# DIRECTORIES
	
	$exc_starting_cluster_data_dir,
	$exc_starting_cluster_dir,
		
	$family_data_dir,
	$mappings_data_dir,
	
	$mapping_data_dir,

	$family_sizes_data_dir,
	$family_core_terms_data_dir,
	$family_term_counts_data_dir,
	$family_anno_data_dir,
	$family_trees_data_dir,

	$family_names_data_dir,
	$family_taxo_data_dir,
		
	$family_mfasta_data_dir,
	$family_alignments_data_dir,
	$family_models_data_dir,
	$family_modlib_data_dir,

	$family_generic_sibling_cluster_data_dir,
	
	$family_modthresh_data_dir,
	
	$family_anno_only_mfasta_data_dir,
	$family_anno_only_nonred_mfasta_data_dir,
	$family_anno_only_nonred_alignments_data_dir,
	
	$benchmark_data_dir,

	$mapping_target_mfasta_data_dir,
	$mapping_scan_data_dir,
	$mapping_assignments_data_dir,
	$mapping_assignments_go_data_dir,
	
	$mapping_seqids_data_dir,
	$mapping_mfasta_data_dir,
	$mapping_alignments_data_dir,

	$mapping_stats_data_dir,
	$mapping_nonred_mfasta_data_dir,
	$mapping_nonred_alignments_data_dir,

	$family_term_counts_dir,
	$family_anno_dir,
		
	$family_mfasta_dir,
	$family_alignments_dir,
	$family_models_dir,

	$family_anno_only_mfasta_dir,
	$family_anno_only_nonred_mfasta_dir,
	$family_anno_only_nonred_alignments_dir,
	
	$family_generic_sibling_cluster_dir,
	
	# FILES

	$superfamily_anno_file,
	
	$superfamily_name_file,
	$superfamily_taxid_file,
	$superfamily_exclude_file,
	
	$superfamily_mfasta_file,
		
	$unsupervised_clustering_flag_file,
	
	$family_sizes_file,
	$family_core_terms_file,
	
	$json_family_tree_file,
	$newick_family_tree_file,
	
	$family_names_file,
	$family_taxo_file,
	
	$family_modlib_file,
	
	$family_siblings_file,

	$family_child_clus_file,
	$family_ec_cons_file,
		
	$model_inc_threshold_file,
	$model_exc_threshold_file,

	$mapping_target_mfasta_file,
	$mapping_scan_file,
	$mapping_assignments_file,
	$mapping_assignments_go_file,
	
	$mapping_stats_file,

	$mapping_seqids_dir,
	$mapping_mfasta_dir,
	$mapping_alignments_dir,
	
	$mapping_nonred_mfasta_dir,
	$mapping_nonred_alignments_dir,
	
	$superfamily_libgen_errors_file,
	
	$superfamily_benchmark_scores_file,
	$superfamily_benchmark_performance_file,
	
);


sub persf_seq2anno_dataset_to_persf_seq_dataset
{

	my $persf_seq_anno_dataset = shift;
	
	my @cols = split "_" . ANNO_TO . "_", $persf_seq_anno_dataset;
	if (@cols < 2)
		{
		die "ERROR: '$persf_seq_anno_dataset' is not a valid per-superfamily annotated sequence dataset!\n";
		}
=cut
	my $seq_file_prefix = $cols[0];	
	@cols = split "_", $cols[-1];	
	my $date_stamp = $cols[-1];

	#DEBUGxxx 
	$seq_file_prefix =~ s/\_seqs//;
=cut
	$persf_seq_dataset = $cols[0];

	$persf_seq_dataset = "$used_shared_data_dir/$persf_seq_dataset";
	$persf_seq_dataset = "$persf_seq_dataset/" . PERSF;

	return $persf_seq_dataset;	
	
}

# a simple shortcut since we use this at several points
sub verify_all_project_input_datasets
{

	verify_project_input_datasets($persf_seq2ukb_dataset,
								  $persf_seq2go_dataset,
								  $go_ontology_hash_file_set,
								  $ukb_taxonomy_hash_file_set);

}

sub verify_project_input_datasets
{

	foreach (@_)
	
		{
		
		if ($_ =~ /\.gz$/)
			{
			print "ERROR: first unpack dataset $_!\n"; exit;
			}
		elsif (! -d "$used_shared_data_dir/$_")
			{
			die "ERROR: $used_shared_data_dir/$_ is not a directory!\n";
			}

		}

}


#DEBUG split off init_superfamily_dirs_and_files and leave only project-spec
#DEBUG things in here
sub init_local_dirs_and_files
{

	my ($project, $superfamily) = @_;
	
	# the generic config file (located automatically, provides $local_base_work_dir)
	common::load_settings(common::PIPELINE_CONFIG_FILE_NAME, 1); 
	
	$base_work_dir = $local_base_work_dir;
	$base_data_dir = $local_base_data_dir;	
	$scripts_dir = "$base_work_dir/local_scripts";
	common::init_generic_dirs_and_files();
	
	# some of those parameters are needed locally too
	common::load_settings($clustering_config_file, 1); 

	# defining paths to third-party tools and parameter settings 
	common::load_settings($thirdpartytools_config_file, 1);
	
	# the only config file specific to the local part of the pipeline
	common::load_settings($annotations_config_file, 1); 

	if ($project eq "none") { return; }
	
	# the project specific project config file
	common::init_project_dirs_and_files($project);
	common::load_project_settings($project);
	
	verify_all_project_input_datasets();
	
	# we need those datasets locally only
	$persf_seq_dataset = persf_seq2anno_dataset_to_persf_seq_dataset($persf_seq2go_dataset);
	$persf_seq2ukb_dataset = "$used_shared_data_dir/$persf_seq2ukb_dataset";
	$persf_seq2go_dataset = "$used_shared_data_dir/$persf_seq2go_dataset";

	$go_ontology_hash_file_set = 
	"$used_shared_data_dir/$go_ontology_hash_file_set/$go_ontology_hash_file_set." . GREPPED;	
	annotations::go_init_hash_file_names($go_ontology_hash_file_set);
	
	$ukb_taxonomy_hash_file_set = 
	"$used_shared_data_dir/$ukb_taxonomy_hash_file_set/" . common::UNIPROT_TAXONOMY_FILE_NAME;
	taxonomy::init_hash_file_names($ukb_taxonomy_hash_file_set);

	#DEBUG do file existence checks for above hash files here?
	
	# PROJECT SPECIFIC
	
	$exc_starting_cluster_data_dir = "$project_data_dir/exc_starting_clusters";
		
	# FAMILY SET SPECIFIC
		
	#NOTE this modifies the global $family_set loaded above (adds _ or not)
	init_family_set_dirs_and_files($family_set);
	
	# SUPERFAMILY SPECIFIC
	
	#DEBUG superfamily specificity not needed so far (only used for CD-HIT with fam-spec filenames)
	$temp_dir = "$temp_data_dir"; #/$superfamily";	
	# override the default Linux temp dir
	$ENV{"TMPDIR"} = $temp_dir;
	
	if ($superfamily eq "none") { return; }
	
	init_superfamily_dirs_and_files($superfamily);
			
}


sub init_family_set_dirs_and_files
{

	my $set = shift;
	$family_set = $set;
	
	$family_granularity = "funfams";
	foreach (@common::clustering_granularity_steps)
		{
		if ($family_set =~ /($_)/)
			{
			$family_granularity = $1; last;
			}
		}
	#DEBUG doesn't work cause $1 is undefined after grep, so above loop instead
	#if (grep { $family_set =~ /($_)/ } @common::clustering_granularity_steps) { $family_granularity = $1; }
	#else { $family_granularity = "funfams"; }

	if ($family_set eq "funfams") { $family_set = ""; } 
	else { $family_set = "_$family_set"; }

	$family_data_dir = "$project_data_dir/families" . $family_set;

	$family_sizes_data_dir = "$family_data_dir/sizes";	
	$family_core_terms_data_dir = "$family_data_dir/coreterms";
	$family_term_counts_data_dir = "$family_data_dir/termcounts";
	$family_anno_data_dir = "$family_data_dir/anno";
	$family_trees_data_dir = "$family_data_dir/trees";
	
	$family_names_data_dir = "$family_data_dir/names";
	$family_taxo_data_dir = "$family_data_dir/taxo";
	
	$family_mfasta_data_dir = "$family_data_dir/mfasta";
	$family_alignments_data_dir = "$family_data_dir/alignments";
	$family_models_data_dir = "$family_data_dir/models";

	$family_generic_sibling_cluster_data_dir = "$family_data_dir/siblings";

	$family_modlib_data_dir = "$family_data_dir/modlib";
	$family_modthresh_data_dir = "$family_data_dir/modthresh";

	$family_anno_only_mfasta_data_dir = "$family_data_dir/mfasta_anno_only";
	$family_anno_only_nonred_mfasta_data_dir = "$family_data_dir/mfasta_anno_only_nonred";
	$family_anno_only_nonred_alignments_data_dir = "$family_data_dir/alignments_anno_only_nonred";
	
	$benchmark_data_dir = "$family_data_dir/benchmark";

}


sub init_superfamily_dirs_and_files
{

	my $superfamily = shift;

	# to be able to use the same input files (e.g. annotation data)
	# with superfamilies from different projects; note that the
	# superfamily name must always start with the same prefix (e.g.
	# the CATH code) followed by a separator and the (project-
	# dependet) rest of the name for this strategy to work; such
	# a name is, for example, "3.40.50.1000_and_cath_and_sfld"
	my @cols = split common::FAMILY_DIR_NAME_SEPARATOR, $superfamily;
	#DEBUG used once; see below!
	my $superfamily_code = $cols[0];

	$superfamily_mfasta_file = "$persf_seq_dataset/$superfamily." . FAA;
	
	$superfamily_clustering_trace_file = "$clustering_output_data_dir/$superfamily.trace";
	
	$starting_cluster_dir = "$starting_cluster_data_dir/$superfamily";	
	$exc_starting_cluster_dir = "$exc_starting_cluster_data_dir/$superfamily";

	$family_term_counts_dir = "$family_term_counts_data_dir/$superfamily";
	$family_anno_dir = "$family_anno_data_dir/$superfamily";

	$family_mfasta_dir = "$family_mfasta_data_dir/$superfamily";
	$family_alignments_dir = "$family_alignments_data_dir/$superfamily";
	$family_models_dir = "$family_models_data_dir/$superfamily";

	$family_generic_sibling_cluster_dir = "$family_generic_sibling_cluster_data_dir/$superfamily";
	
	$family_anno_only_mfasta_dir = "$family_anno_only_mfasta_data_dir/$superfamily";
	$family_anno_only_nonred_mfasta_dir = "$family_anno_only_nonred_mfasta_data_dir/$superfamily";
	$family_anno_only_nonred_alignments_dir = "$family_anno_only_nonred_alignments_data_dir/$superfamily";
	
	$unsupervised_clustering_flag_file = "$exc_starting_cluster_dir/unsupervised";
	
	$family_sizes_file = "$family_sizes_data_dir/$superfamily.sizes";
	$family_core_terms_file = "$family_core_terms_data_dir/$superfamily.coreterms";
	
	$json_family_tree_file = "$family_trees_data_dir/$superfamily.json";
	$newick_family_tree_file = "$family_trees_data_dir/$superfamily.newick";

	$family_names_file = "$family_names_data_dir/$superfamily.names";
	$family_taxo_file = "$family_taxo_data_dir/$superfamily.taxo";
	
	# note that HMMER's hmmpress generates 3 additional files for each single
	# one of these files
	$family_modlib_file = "$family_modlib_data_dir/$superfamily.models";
	
	$family_siblings_file = "$family_generic_sibling_cluster_dir/sibling_cluster_by_family";
	
	#DEBUG could put this somewhere else
	$superfamily_libgen_errors_file = "$family_modlib_file.errors";

	$superfamily_benchmark_scores_file = "$benchmark_data_dir/$superfamily.rawscores";
	#DEBUG not currently used
	$superfamily_benchmark_performance_file = "$benchmark_data_dir/$superfamily.performance";
	#$family_ec_cons_file = "$family_stats_data_dir/$superfamily.ec_cons";

	$model_inc_threshold_file = "$family_modthresh_data_dir/$superfamily.thresholds.inc";
	$model_exc_threshold_file = "$family_modthresh_data_dir/$superfamily.thresholds.exc";

	#DEBUG using $superfamily_code here; see above!
	$superfamily_anno_file = "$persf_seq2go_dataset/$superfamily_code." . ANNO;
	# these data are used in the family naming process
	$superfamily_name_file = "$persf_seq2ukb_dataset/$superfamily_code." . NAMES;
	$superfamily_taxid_file = "$persf_seq2ukb_dataset/$superfamily_code." . TAXIDS;
	$superfamily_exclude_file = "$persf_seq2ukb_dataset/$superfamily_code." . EXCLUDED;
	
}


sub init_mapping_dirs_and_files
{

	my ($mapping, $superfamily) = @_;

	# MAPPING-SPECIFIC

	$mappings_data_dir = "$project_data_dir/mappings" . $family_set;
	
	$mapping_data_dir = "$mappings_data_dir/$mapping";
	
	$mapping_target_mfasta_data_dir = "$mapping_data_dir/target_mfasta";

	$mapping_scan_data_dir = "$mapping_data_dir/scans";
	$mapping_assignments_data_dir = "$mapping_data_dir/assignments";
	$mapping_assignments_go_data_dir = "$mapping_data_dir/assignments_go";
	
	$mapping_seqids_data_dir = "$mapping_data_dir/seqids";
	$mapping_mfasta_data_dir = "$mapping_data_dir/mfasta";
	$mapping_alignments_data_dir = "$mapping_data_dir/alignments";
	
	$mapping_stats_data_dir = "$mapping_data_dir/stats";
	
	$mapping_nonred_mfasta_data_dir = "$mapping_data_dir/mfasta_nonred";
	$mapping_nonred_alignments_data_dir = "$mapping_data_dir/alignments_nonred";

	# SUPERFAMILY-SPECIFIC
	
	$mapping_target_mfasta_file = "$mapping_target_mfasta_data_dir/$superfamily." . FAA;
	$mapping_scan_file = "$mapping_scan_data_dir/$superfamily.hmmscan";
	$mapping_assignments_file = "$mapping_assignments_data_dir/$superfamily.assign";
	$mapping_assignments_go_file = "$mapping_assignments_go_data_dir/$superfamily.assign_go";
	
	$mapping_seqids_dir = "$mapping_seqids_data_dir/$superfamily";
	$mapping_mfasta_dir = "$mapping_mfasta_data_dir/$superfamily";
	$mapping_alignments_dir = "$mapping_alignments_data_dir/$superfamily";

	$mapping_nonred_mfasta_dir = "$mapping_nonred_mfasta_data_dir/$superfamily";
	$mapping_nonred_alignments_dir = "$mapping_nonred_alignments_data_dir/$superfamily";

	$mapping_stats_file = "$mapping_stats_data_dir/$superfamily.mapstats";

}


#EOF
1;
