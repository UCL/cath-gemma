#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package prepare;

#NOTExxx taxon was replaced by organism-id recently, prone to change again in 2013!

use strict;

use common;
use annotations;
use taxonomy;
use fasta;

#DEBUG move to common.pm
my $temp_file_prefix = "temp";

#DEBUG could have more globals, e.g. $dataset
my ($output_dir, $temp_output_dir, $temp_path, $temp_path2, $ext);

sub select_dataset
{

	my ($dataset_type, $base_dir, $name_pattern, $hide_pattern) = @_;

	opendir my $DH, $base_dir || die "ERROR: prepare input data first (prepare)\n";
	my @matches = sort {$a eq $b} grep(/$name_pattern/, readdir($DH));
	closedir $DH;
	
	my @options;		
	foreach (@matches)
		{
		#DEBUGxxx a var like $hide_pattern or $temp_file_prefix doesn't
		#DEBUGxxx work in regex
		if (($_ =~ /(^temp|temp$)/)) { next; }	
		push @options, $_;
		}

	if (! @options) { return 0; }

	print "Please select the $dataset_type dataset\:\n";
	for (my $i = 1; $i<=@options; $i++) { print "[$i] $options[$i-1]\n"; }
		
	my $choice = -1;
	while ($choice < 1 || $choice > @options)
		{
		print "your choice: ";
		$choice = <>;
		chomp $choice;
		if (! $choice) { $choice = -1; next; }
		#DEBUG we'd have to disable warnings to avoid one here
		if (! int($choice)) { $choice = -1; next; }
		}
	
	return $options[$choice-1];
	
}


sub select_dataset_and_main_file
{

	my ($dataset_type, $search_dir, $dataset_dir_pattern, $main_file_pattern) = @_;

	#DEBUG temp
	my $dataset = select_dataset($dataset_type, 
								 $search_dir, 
								 $dataset_dir_pattern, "");
	if (! $dataset)
		{
		return ("", "");
		}
	
	if (! -d "$search_dir/$dataset")
		{
		die "ERROR: $dataset must be a directory in $search_dir\n";
		}
				
	my @main_file = <$search_dir/$dataset/$main_file_pattern>;
	my $main_file = $main_file[0];
	
	if (! -e $main_file)
		{ 
		die "ERROR: main file [$main_file_pattern] not found in dataset $dataset!\n"; 
		}

	my @cols = split /\//, $main_file;
	$main_file = $cols[-1];
		
	return ($dataset, $main_file);
		
}


sub wget_optionally_zipped_file_with_date_stamp
{

	my ($url, $file, $target_dir) = @_;
	
	my $ext = "";
	if ($file =~ /\.gz$/) { $file =~ s/\.gz$//; $ext = "." . GZ; }
	
	#DEBUGxxx necessary? doesn't wget do it's own temp thing with ".xxx" files?
	my $output_file = "$file\_$date_stamp$ext";
	my $temp_output_file = "$temp_file_prefix\_$output_file";
	
	if (0 != system(SYSTEM_CALL_WGET . " $url/$file$ext -O $target_dir/$temp_output_file"))
		{
		die "ERROR: cannot wget $url/$file$ext! (see $target_dir/$temp_output_file)\n";
		}

	system(SYSTEM_CALL_MV . " $target_dir/$temp_output_file $target_dir/$output_file"); 
	
	return $output_file;

}


sub cat_or_unzip_for_pipe_cmd
{

	my ($file, $pipe_cmd) = @_;

	# user-given file might not be packaged!
	if ($file =~ /\.gz$/)
		{ $pipe_cmd = SYSTEM_CALL_GUNZIP . " -c $file | $pipe_cmd"; }
	else
		{ $pipe_cmd = SYSTEM_CALL_CAT . " $file | $pipe_cmd"; }

	return $pipe_cmd;
		
}


sub unpack_if_packed
{

	my $dataset = shift;
	
	if (-d $dataset) { return 0; }
	
	if ($dataset =~ /\.gz$/)
		{
		#DEBUG
		print "unpacking $dataset...\n";
		if (system(SYSTEM_CALL_GUNZIP . " $dataset") == 0)
			{
			return 1;
			}
		}
		
	return 0;

}


sub pack_if_unpacked
{

	my $dataset = shift;
	
	if (-d $dataset) { return 0; }
	
	if ($dataset !~ /\.gz$/)
		{
		print "packing $dataset...\n";
		if (system(SYSTEM_CALL_GZIP . " $dataset") == 0)
			{
			return 1;
			}
		}
		
	return 0;

}


sub prepare_dataset_paths
{

	my ($data_dir, $dataset) = @_;
	
	my $temp_output_dir = "$temp_file_prefix\_$dataset";

	my $path = "$data_dir/$dataset";
	if (-d $path)
		{ print "ERROR: $path already exists! (remove first?)\n"; exit; }
	#common::rm_dir_if_exists($path);
	#NOTE this path is created later on by the calling code
	
	$path = "$data_dir/$temp_output_dir";
	if (-d $path)
		{ print "ERROR: $path already exists! (concurrent process?)\n"; exit; }
	common::new_dir_if_nexists($path);	

	return ($dataset, $temp_output_dir);
	
}


sub filter_mapping_file_by_prot_ids_from_seq_file
{

	my ($in_file, $seq_file_full_path, $out_file) = @_;

	my ($ref, $seq_count) = 
	fasta::load_headers_from_faa_file($seq_file_full_path);
	my @prot_seq_ids = map { common::trunc_seq_header($_) } @{$ref};
	
	print "filtering mapping for sequences actually present in the sequence dataset...\n";
	#DEBUG could do this already after getting the unfiltered file from the server/user
	#DEBUG right now we do it whenever we prepare a sequence dataset
	#NOTE the reversed key and value columns (as we want id by acc, not vice versa as in the file)

	my %prot_id_by_acc = 
	%{common::load_hash_with_scalar_value_filtered
	($in_file, DRCS, 1, 0, 0, \@prot_seq_ids)};
	#DEBUGxxx
	common::write_hash(\%prot_id_by_acc, $out_file, DWCS);
								
}


sub select_prot_id_to_ukb_acc_mapping_and_filter
{

	my $seq_file_full_path = shift;

	my $prot_id_to_ukb_acc_mapping = 
	select_dataset("protein ID to UniProt accession", 
				   $processed_shared_data_dir, TO_UNIPROT_IDS, "");
	if (! $prot_id_to_ukb_acc_mapping)
		{
		print "ERROR: prepare a protein id to UKB accession mapping first (prepare idmapping)\n"; exit;
		}
				
	$prot_id_to_ukb_acc_mapping = "$processed_shared_data_dir/$prot_id_to_ukb_acc_mapping";
	if (! -e $prot_id_to_ukb_acc_mapping)
		{ die "ERROR: $prot_id_to_ukb_acc_mapping not found in $processed_shared_data_dir!\n"; }
		
	#DEBUG could save it after filtering
	my $temp_file = $prot_id_to_ukb_acc_mapping . ".filtered.temp";
	if (! -e $temp_file)
		{
		filter_mapping_file_by_prot_ids_from_seq_file
		($prot_id_to_ukb_acc_mapping, $seq_file_full_path, $temp_file);
		}
	$prot_id_to_ukb_acc_mapping = $temp_file;
		
	return $prot_id_to_ukb_acc_mapping;
	
}


sub prepare_uniprot_kb_dataset
{

	sub query_webservice
		
		{
		
		my $get_what = shift;
		my $url = shift;
		my $ref = shift; my @parameters = @{$ref};
		my $output_file = shift;
		
		print $get_what . "\n";
				
		my $parameters = join "&", @parameters;
		
		my $call = SYSTEM_CALL_CURL . " -w '%{http_code}\\n'" . " \'$url$parameters";
		
		# if the compress parameter is used omit it when 'pinging' the service
		$call =~ s/\&compress\=yes//;
		
		#NOTE we are closing the above "'" here
		my @cols = `$call\&limit=1\' | tail -n1`;

		chomp @cols;
		if ($cols[-1] != 200)
			{
			die "ERROR: $url returns status code $cols[-1]! (temporary problems?)\n";
			}
				
		#DEBUG see below too
		#$output_file .= "_$date_stamp";
		#NOTE we are closing the above "'" here
		system(SYSTEM_CALL_CURL . " \'$url$parameters\' >$output_file");
				
		}

	my $dataset = common::UNIPROT_DATA_DIR_PREFIX . $date_stamp;

	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($used_shared_data_dir, $dataset);
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($raw_shared_data_dir, $dataset);
	
	$temp_path = "$raw_shared_data_dir/$temp_output_dir";
		
	#DEBUG define in common.pm as file below
	my $ukb_sprot_accs_file = "$temp_path/" . common::UNIPROT_SPROT_ID_LIST_FILE_NAME;
	my $ukb_excluded_accs_file = "$temp_path/" . common::UNIPROT_FRAGMENT_ID_LIST_FILE_NAME;

	my $ukb_protname_file = "$temp_path/" . common::UNIPROT_ACC2NAME_FILE_NAME;
	my $ukb_prottax_file = "$temp_path/" . common::UNIPROT_ACC2TAXON_FILE_NAME;
	my $ukb_protlen_file = "$temp_path/" . common::UNIPROT_ACC2LENGTH_FILE_NAME;

	my $ukb_taxonomy_file = "$temp_path/" . common::UNIPROT_TAXONOMY_FILE_NAME;

	#NOTE the following commands query the UniProt webservices
	
	print "retrieving data from UniProt...\n";
	
	# UKB main webservice
		
	query_webservice("SwissProt accessions", $raw_data_ukb_webservice_seqdb_url,
					["query=reviewed:yes", "format=tab", "columns=id", "compress=yes"],
					"$ukb_sprot_accs_file." . GZ);

	query_webservice("low-quality entry accessions", $raw_data_ukb_webservice_seqdb_url,
					["query=fragment:yes", "format=tab", "columns=id", "compress=yes"],
					"$ukb_excluded_accs_file." . GZ);

	query_webservice("protein name information", $raw_data_ukb_webservice_seqdb_url,
					["query=*", "format=tab", "columns=id,protein%20names", "compress=yes"],
					"$ukb_protname_file." . GZ);

	query_webservice("protein taxon information", $raw_data_ukb_webservice_seqdb_url,
					["query=*", "format=tab", "columns=id,organism-id", "compress=yes"],
					"$ukb_prottax_file." . GZ);				
	
	query_webservice("protein length information", $raw_data_ukb_webservice_seqdb_url,
					["query=*", "format=tab", "columns=id,length", "compress=yes"],
					"$ukb_protlen_file." . GZ);	
	
	# UKB taxonomy webservice
	
	query_webservice("taxonomy information", $raw_data_ukb_webservice_taxdb_url,
					["query=*", "format=tab", "compress=yes"],
					"$ukb_taxonomy_file." . GZ);	
	
	print "\n";

	print "unpacking...\n";
	foreach ($ukb_sprot_accs_file, $ukb_excluded_accs_file, 
			 $ukb_protname_file, $ukb_taxonomy_file, 
			 $ukb_protlen_file)
		{
		system(SYSTEM_CALL_GUNZIP . " $_\." . GZ);
		}

	
	print "deriving hash files from $ukb_taxonomy_file ...\n";
	taxonomy::init_hash_file_names($ukb_taxonomy_file);
	taxonomy::init_hashes($ukb_taxonomy_file);

	$temp_path = "$used_shared_data_dir/$temp_output_dir";
	common::new_or_clear_dir($temp_path);
	
	#print "moving files to final destinations...\n";	
	#NOTE only the derived hash files are used later on
	system(SYSTEM_CALL_MV . " $ukb_taxonomy_file.* $temp_path");
	
#=cut
	#DEBUG
	print "repacking...\n";
	foreach ($ukb_sprot_accs_file, $ukb_excluded_accs_file, 
			 $ukb_protname_file, $ukb_taxonomy_file, 
			 $ukb_protlen_file)
		{
		system(SYSTEM_CALL_GZIP . " $_");
		}
#=cut		
	
	$temp_path = "$used_shared_data_dir/" . common::UNIPROT_TAXONOMY_FILE_NAME . "\_$date_stamp";
	common::new_or_clear_dir($temp_path);

	system(SYSTEM_CALL_MV . " $raw_shared_data_dir/$temp_output_dir $raw_shared_data_dir/$output_dir");
	system(SYSTEM_CALL_MV . " $used_shared_data_dir/$temp_output_dir $temp_path");
	
	print "done.\n";

}


sub prepare_go_and_uniprot_goa_dataset
{

	my $dataset = common::GO_DATA_DIR_PREFIX . $date_stamp;

	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($raw_shared_data_dir, $dataset);
	
	$temp_path = "$raw_shared_data_dir/$temp_output_dir";
		
	print "retrieving GO annotations from $raw_data_ukbgoa_ftp_url ...\n";
	wget_optionally_zipped_file_with_date_stamp($raw_data_ukbgoa_ftp_url, 
	"$ukbgoa_gene_association_file" . "." . GZ, $temp_path);

	print "retrieving GO term definitions & hierarchy from $raw_data_go_ftp_url ...\n";
	$go_ontology_oboxml_file = 
	wget_optionally_zipped_file_with_date_stamp($raw_data_go_ftp_url, 
	$go_ontology_oboxml_file . "." . GZ, $temp_path);

	print "processing data...\n";
		
	#DEBUG could create a sub annotations::go_condense_obo_xml_file($go_ontology_oboxml_file);	
	#print "grepping $file for size reduction...\n";

	my $cmd = SYSTEM_CALL_EGREP . " '<term>|<name>|<namespace>|<id>GO|<is_a>GO|<is_obsolete>1'";
	$cmd = cat_or_unzip_for_pipe_cmd("$temp_path/$go_ontology_oboxml_file", $cmd);
	$go_ontology_oboxml_file =~ s/\.gz$//;

	$go_ontology_hash_file_set = $go_ontology_oboxml_file;
	$go_ontology_oboxml_file = "$temp_path/$go_ontology_oboxml_file";
	
	$go_ontology_oboxml_file .= "." . GREPPED;
	system("$cmd > $go_ontology_oboxml_file");

	# remove header; strips everything before the first term record in this XML file
	common::remove_file_lines_before_match($go_ontology_oboxml_file, annotations::GO_OBO_XML_FILE_TERM_TAG);

	#print "deriving hash files from $go_ontology_oboxml_file ...\n";
	annotations::go_init_hash_file_names($go_ontology_oboxml_file);
	annotations::go_init_hashes();

	#DEBUG it's only a single file so don't create a subdir
	#print "moving files to final destinations...\n";	
	system(SYSTEM_CALL_MV . " $go_ontology_oboxml_file $processed_shared_data_dir");
	
	$temp_path = "$used_shared_data_dir/$go_ontology_hash_file_set";
	common::new_or_clear_dir($temp_path);
	#NOTE only the derived hash files are used later on
	system(SYSTEM_CALL_MV . " $go_ontology_oboxml_file.* $temp_path");

	system(SYSTEM_CALL_MV . " $raw_shared_data_dir/$temp_output_dir $raw_shared_data_dir/$output_dir");
	
	print "done.\n";
	
}


sub prepare_idmapping_dataset
{

	#DEBUG
	my $final_mapping_file_prefix = "gene3d";
	my $final_mapping_file_suffix = "\_" . TO_UNIPROT_IDS . "\.tdl" . "\_$date_stamp";
	
	#DEBUG could make these standard settings for the $g3d_ukb_assignments_file 
	#DEBUG constants somewhere
	my ($delim, $key_col, $val_col) = (",", 1, 2);
				
	#DEBUGxxx make this use any file in any path
	print 
#"This will format the protein id mapping data.
"Please provide a protein id to UniProt accession mapping file 
(column numbers and separator type not important) in $idmappings_data_dir 
OR press Enter to use the latest Gene3D to UniProt mapping\n";
	print ":"; my $raw_mapping_file = <>; chomp $raw_mapping_file;
	
	# get from FTP server
	if (! $raw_mapping_file)
		{
		
		$raw_mapping_file = $g3d_ukb_assignments_file . "." . GZ;

		#DEBUGxxx
		print "retrieving latest Gene3D md5 to UniProt accession mapping from $raw_data_g3d_ftp_url...\n"; 
		$raw_mapping_file = wget_optionally_zipped_file_with_date_stamp($raw_data_g3d_ftp_url, $raw_mapping_file, $idmappings_data_dir);
	
		#DEBUGxxx not ideal, rewire this
		system(SYSTEM_CALL_MV . " $idmappings_data_dir/$raw_mapping_file $idmappings_data_dir/$final_mapping_file_prefix\_$raw_mapping_file");
		$raw_mapping_file = "$final_mapping_file_prefix\_$raw_mapping_file";
		}
	
	# prepare from a local file
	else
		{
		
		#DEBUG could make a sub get_file_name with a loop that waits until it's a proper file
		if (! -e "$idmappings_data_dir/$raw_mapping_file") 
			{ print "ERROR: $idmappings_data_dir\/$raw_mapping_file not found!\n"; exit; }
		
		print "Please provide the type of protein IDs you are mapping to UniProt accessions in one word OR press Enter to use 'gene3d'\n";
		my $input = <>; chomp $input;
		if ($input) { $final_mapping_file_prefix = $input; }
		
		my @cols = ();
		while (@cols != 3)
			{
			print "Please provide the column delimiter and the numbers of the protein id and UniProt accession columns, space-delimited OR press Enter to use the default values [\'$delim\', $key_col, $val_col]\n";
			my $input = <>; chomp $input;
			if (! $input) { @cols = ($delim, $key_col, $val_col); }
			else { @cols = split /\s+/, $input; }			}
		#DEBUG should check for value types here
		($delim, $key_col, $val_col) = @cols;
	
		}

	my $final_mapping_file = $final_mapping_file_prefix . $final_mapping_file_suffix;
		
	#system(SYSTEM_CALL_MV . " $raw_shared_data_dir/$raw_mapping_file $raw_shared_data_dir/$final_mapping_file_prefix\_$raw_mapping_file");
	#$raw_mapping_file = "$raw_shared_data_dir/$final_mapping_file_prefix\_$raw_mapping_file";
	#$raw_mapping_file = "$idmappings_data_dir/$raw_mapping_file";
	$raw_mapping_file = "$idmappings_data_dir/$raw_mapping_file";

	
	print "processing...\n";

	# we always convert to our standard delimiter format
	my $out_delim = common::DWCS;
	#NOTE $key_col (e.g. md5) must always be smaller than (left from) $val_col
	# cut out mapping columns, make unique, replace delimiter
	#DEBUG this sort can cause a lot of mem/disk to be used
	my $cmd = SYSTEM_CALL_CUT . " -f$key_col,$val_col -d $delim | " . 
			  SYSTEM_CALL_SORT_UNIQUE . " | " . SYSTEM_CALL_SED . " 's/$delim/$out_delim/'";
	$cmd = cat_or_unzip_for_pipe_cmd($raw_mapping_file, $cmd);

	#DEBUG temp
	my $temp_final_mapping_file = "$temp_file_prefix\_$final_mapping_file";
	system("$cmd > $processed_shared_data_dir/$temp_final_mapping_file");
	system(SYSTEM_CALL_MV . " $processed_shared_data_dir/$temp_final_mapping_file $processed_shared_data_dir/$final_mapping_file");
	
	print "done.\n";		
	
}


sub prepare_seq2ukb_dataset
{

	#DEBUG
	#$date_stamp = "test";

	#DEBUG could have an option to use latest Gene3D FASTA, 
	#DEBUG but FTP site currently only has SF-specific ones
	print 
#"This will format the sequence data and generate superfamily-specific files.
"Please provide a domain sequence *.faa(.gz) file (see manual for exact format)\n";
	my $seq_file = ""; while (! $seq_file) { print ":"; $seq_file = <>; chomp $seq_file; }
	#DEBUG should build generic checking subs for file name input
	#if ($seq_file =~ "/") { print "ERROR: please enter only the file name, omitting the path\n"; exit; }
	if (! -e $seq_file) { die "ERROR: $seq_file does not exist!\n"; }
	if ($seq_file !~ /\.(faa|gz)$/) { print "ERROR: $seq_file is not a *.faa(.gz) file!\n"; exit; }
	
	my $seq_file_full_path = $seq_file;
	$seq_file = common::strip_path($seq_file);
	my $prefix = $seq_file; $prefix =~ s/\.gz$//; $prefix =~ s/\.faa$//;
	my $seq_dataset = common::DOMSEQ_DATA_DIR_PREFIX . $prefix . "\_$date_stamp";
	
	# --- load UKB dataset ---
	
	# arbitrary choice, we check for all the files in the dataset below
	my $file_name_pattern = common::UNIPROT_ACC2NAME_FILE_NAME;
	my ($ukb_dataset, $ukb_file) = 
	select_dataset_and_main_file("UniProtKB", $raw_shared_data_dir, common::UNIPROT_DATA_DIR_PREFIX, $file_name_pattern);
	if (! $ukb_dataset)
		{ 
		print "ERROR: prepare a UniProtKB dataset first! (prepare ukbdata)\n"; exit; 
		}	
	#DEBUG could do some serious unpacking/repacking for UKB files too, see below
	$temp_path = "$raw_shared_data_dir/$ukb_dataset";
	
	my $ukb_protname_file = "$temp_path/" . common::UNIPROT_ACC2NAME_FILE_NAME;
	my $ukb_prottax_file = "$temp_path/" . common::UNIPROT_ACC2TAXON_FILE_NAME;
	my $ukb_protlen_file = "$temp_path/" . common::UNIPROT_ACC2LENGTH_FILE_NAME;
	my $ukb_excluded_accs_file = "$temp_path/" . common::UNIPROT_FRAGMENT_ID_LIST_FILE_NAME;
	
	my %processed_file_to_ukb_input_file = 
	( 
	
		NAMES, $ukb_protname_file,
		TAXIDS, $ukb_prottax_file,
		LENGTHS, $ukb_protlen_file,
		EXCLUDED, $ukb_excluded_accs_file
	
	);
		
	foreach ($ukb_excluded_accs_file, $ukb_protname_file, 
			 $ukb_prottax_file, $ukb_protlen_file)
		{
		if (! -e $_) { die "ERROR: $_ not found in $ukb_dataset!\n"; }
		}
	
	# --- load ID mapping ---
	
	my $prot_id_to_ukb_acc_mapping = 
	select_prot_id_to_ukb_acc_mapping_and_filter($seq_file_full_path);
	
	
	print "processing...\n";
	
#=cut	
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($raw_shared_data_dir, $seq_dataset);		
	$temp_path = "$raw_shared_data_dir/$temp_output_dir";
	
	#DEBUG could rename to generic name here, e.g., sequences.faa, same for all other data files since
	#DEBUG we now follow a data dir naming regime that includes all relevant info, so the files inside
	#DEBUG these dirs can have generic names
	system(SYSTEM_CALL_COPY . " $seq_file_full_path $temp_path/");
	$seq_file_full_path = "$temp_path/$seq_file";
	
	if (unpack_if_packed($seq_file_full_path))
		{ $seq_file_full_path =~ s/\.gz$//; }
			
	#DEBUGxxx move to end below? change name in that case
	system(SYSTEM_CALL_MV . " $raw_shared_data_dir/$temp_output_dir $raw_shared_data_dir/$output_dir");
	
#=cut	
	$seq_file_full_path = "$raw_shared_data_dir/$seq_dataset/$seq_file";

	my $seq2ukb_dataset = $seq_dataset . "_" . ANNO_TO . "_" . $ukb_dataset;
			
#=cut
	# generate full mapping files
	print "generating $seq2ukb_dataset full mappings...\n";
	
	my %prot_id_by_acc = 
	%{common::load_hash_with_scalar_value($prot_id_to_ukb_acc_mapping, 
										  DRCS, 0, 1)};	

	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($processed_shared_data_dir, $seq2ukb_dataset);
	$temp_path = "$processed_shared_data_dir/$temp_output_dir";
	
	# convert UKB acc to value files to prot_id (md5) to value files
	foreach $ext (NAMES, TAXIDS, LENGTHS, EXCLUDED)
		{
		my $output_file = "$temp_path/$seq2ukb_dataset.$ext";
		#DEBUGxxx create filter_hash_file in common.pm
		open my $INF, "<$processed_file_to_ukb_input_file{$ext}";
		open my $OUF, ">$output_file";
		while (<$INF>)
			{
			chomp;
			my @cols = split DWCS;
			#DEBUG hack so that it works for single-column files too
			push @cols, "";
			if (exists $prot_id_by_acc{$cols[0]})
				{
				my $s = join DWCS, @cols;
				print $OUF $prot_id_by_acc{$cols[0]} . DWCS . $cols[1] . "\n"; 
				}
			}
		close $OUF;
		close $INF;
		}

	system(SYSTEM_CALL_MV . " $processed_shared_data_dir/$temp_output_dir $processed_shared_data_dir/$output_dir");

	# generate sf sequence files	
	print "generating $seq_dataset per-SF sequence files...\n";
	
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($used_shared_data_dir, $seq_dataset);
	$temp_path = "$used_shared_data_dir/$temp_output_dir/" . PERSF;
	common::new_or_clear_dir($temp_path);

	#NOTE the prot length info is used in the called script to calc dom coverage
	my $prot_length_file = "$processed_shared_data_dir/$seq2ukb_dataset/$seq2ukb_dataset." . LENGTHS;
	my $prot_exclude_file = "$processed_shared_data_dir/$seq2ukb_dataset/$seq2ukb_dataset." . EXCLUDED;

	#DEBUG could verify header format first, e.g., by checking first header in file?
	system("$scripts_dir/create_sf_sequence_files.pl $seq_file_full_path " . 
		   "'" . SEQ_HEADER_SFCODE_SEPARATOR . "' " . SEQ_HEADER_SFCODE_COLUMN . 
		   " $prot_length_file $temp_path >" . STDOUT_REDIRECT);
		   
	#NOTE the above script produces a couple of extra files we need to move
	$superfamilies_list_file = "$seq_file_full_path." . SFS;
	$superfamilies_size_file = "$seq_file_full_path." . SFS . "." . SIZES;
	#DEBUG the following files are also produced by above script, but
	#DEBUG so far we don't use them anywhere, so keep them where they are
	#DEBUGxxx make "prot2mda" and ".sizes" constants like SFS
	#DEBUGxxx here and in above called script
	#my $prot2mda_file = "$seq_file_full_path.prot2mda";
	#my $prot2domcov_file = "$seq_file_full_path.prot2domcov";
	
	#DEBUG the /.. is not ideal here
	system(SYSTEM_CALL_COPY . " $superfamilies_list_file $temp_path/../" . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME);
	system(SYSTEM_CALL_COPY . " $superfamilies_size_file $temp_path/../" . common::PROJECT_SUPERFAMILIES_SIZE_FILE_NAME);
	#DEBUG if we didn't want to keep any files in the original dir (see
	#DEBUG above) we could move all of them like this:
	#system(SYSTEM_CALL_MV . " $seq_file_full_path.* $temp_path");

	#DEBUGxxx ask first! if we don't repack it we save time in the seq2anno step
	#DEBUGxxx, can then repack it (see there)
	#pack_if_unpacked($seq_file_full_path);
	
	system(SYSTEM_CALL_MV . " $used_shared_data_dir/$temp_output_dir $used_shared_data_dir/$output_dir");
#=cut

	# generate sf-specific mapping files	
	print "generating $seq2ukb_dataset per-SF mappings...\n";
	
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($used_shared_data_dir, $seq2ukb_dataset);
	$temp_path = "$used_shared_data_dir/$temp_output_dir/" . PERSF;
	#$temp_path = "$used_shared_data_dir/$seq2ukb_dataset/" . PERSF;

	common::new_or_clear_dir($temp_path);

	# we've just created and populated that one above
	my $persf_seq_dataset = "$used_shared_data_dir/$seq_dataset/" . PERSF;
	#$superfamilies_list_file = "$used_shared_data_dir/$seq_dataset/" . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME;
	
	#DEBUG we don't use protein length information anywhere thus far
	foreach $ext (EXCLUDED, NAMES, TAXIDS) # LENGTHS 
		{
	
		#print "$ext\n";
		
		my $in_file = "$processed_shared_data_dir/$seq2ukb_dataset/$seq2ukb_dataset." . $ext;
	
		system("$scripts_dir/create_sf_mapping_files.pl " .
			   "$in_file " .
			   "$persf_seq_dataset " .
			   "$superfamilies_list_file " .
			   "$temp_path $ext >" . STDOUT_REDIRECT);
		
		}
		
	system(SYSTEM_CALL_MV . " $used_shared_data_dir/$temp_output_dir $used_shared_data_dir/$output_dir");

	print "done.\n";	

}


sub prepare_seq2anno_dataset
{

	my $file_name_pattern = "*." . FAA . "*";
	my ($seq_dataset, $seq_file) = 
	select_dataset_and_main_file("sequence", $raw_shared_data_dir, common::DOMSEQ_DATA_DIR_PREFIX, $file_name_pattern);
	if (! $seq_dataset)
		{
		print "ERROR: prepare a sequence dataset first! (prepare seqdata)\n"; exit;
		}

	my $superfamilies_list_file = "$used_shared_data_dir/$seq_dataset/" . common::PROJECT_SUPERFAMILIES_LIST_FILE_NAME;
	if (! -e $superfamilies_list_file)
		{ die "ERROR: $superfamilies_list_file not found!\n"; }
		
	#my $prefix = $seq_file; $prefix =~ s/\.faa$//; $prefix =~ s/\.gz$//; 
	#DEBUGxxx
	my $persf_seq_dataset = "$used_shared_data_dir/$seq_dataset/" . PERSF;
	if (! -d $persf_seq_dataset) 
		{ 
		print "ERROR: per-SF sequence dataset not found! (repeat: prepare seqdata)\n"; exit; 
		}
				
	my $seq_file_full_path = "$raw_shared_data_dir/$seq_dataset/$seq_file";
	my $seq_unpack_flag = unpack_if_packed($seq_file_full_path);
	if ($seq_unpack_flag) { $seq_file_full_path =~ s/\.gz$//; }
	
	# --- load GOA dataset ---

	$file_name_pattern = "$ukbgoa_gene_association_file*";
	my ($go_dataset, $goa_file) = 
	select_dataset_and_main_file("UniProt-GOA", $raw_shared_data_dir, common::GO_DATA_DIR_PREFIX, $file_name_pattern);
	if (! $go_dataset)
		{ 
		print "ERROR: prepare an annotation dataset first! (prepare annodata)\n"; exit; 
		}
	
	my $goa_file_full_path = "$raw_shared_data_dir/$go_dataset/$goa_file";
	my $anno_unpack_flag = unpack_if_packed($goa_file_full_path);

	#DEBUG
	#print "$goa_file\n";

	if ($anno_unpack_flag) 
		{ 
		$goa_file_full_path =~ s/\.gz$//; 
		$goa_file =~ s/\.gz$//; 
		}	
	
	# --- load UKB dataset ---

	# arbitrary choice, we check for all the files in the dataset below
	$file_name_pattern = common::UNIPROT_SPROT_ID_LIST_FILE_NAME;
	my ($ukb_dataset, $ukb_file) = 
	select_dataset_and_main_file("UniProtKB", $raw_shared_data_dir, common::UNIPROT_DATA_DIR_PREFIX, $file_name_pattern);
	if (! $ukb_dataset)
		{ 
		print "ERROR: prepare a UniProtKB dataset first! (prepare ukbdata)\n"; exit; 
		}	
	#DEBUG could do some serious unpacking/repacking for UKB files too, see below
	#$temp_path = "$raw_shared_data_dir/$ukb_dataset";
	my $ukb_sprot_accs_file = "$raw_shared_data_dir/$ukb_dataset/$ukb_file";
	
	# --- load ID mapping ---
	
	my $prot_id_to_ukb_acc_mapping = 
	select_prot_id_to_ukb_acc_mapping_and_filter($seq_file_full_path);

	
	print "processing...\n";
	
	my %prot_id_by_acc = 
	%{common::load_hash_with_scalar_value($prot_id_to_ukb_acc_mapping, 
										  DRCS, 0, 1)};	

	#DEBUGxxx
	#$file_name_pattern = $goa_file;
	#$file_name_pattern =~ s/gene_association\.//;
	#my $seq2go_dataset = $seq_dataset . "_" . ANNO_TO . "_" . $file_name_pattern;
	my $seq2go_dataset = $seq_dataset . "_" . ANNO_TO . "_" . $go_dataset;
	
	# generate full mapping files
	print "generating $seq2go_dataset full mappings...\n";

	my @sprot_prot_ids = @{common::load_list($ukb_sprot_accs_file)};
	
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($processed_shared_data_dir, $seq2go_dataset);		
	$temp_path = "$processed_shared_data_dir/$temp_output_dir";
	
	my ($ref, $ref2) =
	annotations::go_load_goa_file($goa_file_full_path, \%prot_id_by_acc,
								  \@sprot_prot_ids);
	
	my %terms_by_prot_id = %{$ref};
	my %ecs_by_prot_id = %{$ref2};
	
	open my $ANF, ">$temp_path/$seq2go_dataset." . ANNO;
	#NOTE we do not remove parent terms (see annotations::go_load_goa_file() NOTE)
	foreach (keys %terms_by_prot_id)
		{
		my $output = "$_" . DWCS . join ";", sort keys %{$terms_by_prot_id{$_}};		
		if (exists $ecs_by_prot_id{$_}) 
			{
			$output .= DWCS . join ";", sort keys %{$ecs_by_prot_id{$_}};
			}
		else
			{
			$output .= DWCS . "none";
			}

		print $ANF "$output\n";	
		}
	close $ANF;

	system(SYSTEM_CALL_MV . " $processed_shared_data_dir/$temp_output_dir $processed_shared_data_dir/$output_dir");

	
	# generate sf-specific mapping files	
	print "generating $seq2go_dataset per-SF mappings...\n";
	
	($output_dir, $temp_output_dir) = 
	prepare_dataset_paths($used_shared_data_dir, $seq2go_dataset);
	$temp_path = "$used_shared_data_dir/$temp_output_dir/" . PERSF;
	common::new_or_clear_dir($temp_path);

	foreach $ext (ANNO) # think about ANNO.GO and ANNO.EC
		{
	
		#print "$ext\n";
		
		my $in_file = "$processed_shared_data_dir/$seq2go_dataset/$seq2go_dataset." . $ext;
	
		system("$scripts_dir/create_sf_mapping_files.pl " .
		       "$in_file " .
		       "$persf_seq_dataset " .
		       "$superfamilies_list_file " .
		       "$temp_path $ext >" . STDOUT_REDIRECT);
		
		}
		
	system(SYSTEM_CALL_MV . " $used_shared_data_dir/$temp_output_dir $used_shared_data_dir/$output_dir");

	#DEBUGxxx unless debugging we normally want to do this
	#DEBUGxxx (takes some time but saves space)
	#DEBUG better put pack_if_unpacked() calls here
	#if ($anno_unpack_flag) { system(SYSTEM_CALL_GZIP . " $goa_file_full_path"); }
	#if ($seq_unpack_flag) { system(SYSTEM_CALL_GZIP . " $goa_file_full_path"); }
				
	print "done.\n";
	
}


#EOF
1;
