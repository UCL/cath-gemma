#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package funcclusters;

use strict;

use common;
use fasta;


#DEBUG could put those in a config file instead
use constant
{

	# if pattern appears in a protein name: do not use the name at all
	PROTEIN_NAME_PATTERNS_EXCLUDE => qr/(\:|\_|\||--|-like|conserved|superfamily|domain|containing|expressed|clone|bifunct|trifunct|fragment|isoform|chromosome|genomic|partially|confirmed|similar|predicted protein|putative unchara|^unchara|unknown|novel|homolog)/i,

	# if pattern appears in a protein name: use only the rest of the name
	PROTEIN_NAME_PATTERNS_TRUNCATE => qr/^(protein|possible|predicted|probable|putative)/i,

	MAX_FAMILY_NAME_LENGTH => 50,

	FAMILY_NAME_SUFFIX => ' -like domain'

};

use constant 

#DEBUG should put this in a config file instead
{ HMMER_OUTPUT_COLUMN_SEPARATOR => qr/\s+/, HMMER_SEARCH_OUTPUT_HEADER_LINES => 3, HMMER_SCAN_OUTPUT_HEADER_LINES => 3 };

use constant

{ FIRST_ARTIFICIAL_NODE_ID => 1000000 };


sub load_cluster_dir
{

	my ($cluster_dir, $extension) = @_;	

	my ($cluster, $seq_count, %seq_ids_by_cluster, %anno_seq_ids_by_cluster, 
		%cluster_size, @filtered, $ref);

	#foreach (<$cluster_dir/*.$extension>)
	foreach (@{common::safe_glob("$cluster_dir/*.$extension")})
	
		{

		$cluster = $_; $cluster =~ s/$cluster_dir\///; $cluster =~ s/\.$extension//;
								
		($ref, $seq_count) = fasta::load_headers_from_faa_file($_);
		
		$seq_ids_by_cluster{$cluster} = $ref;
		
		}
				
	return \%seq_ids_by_cluster;
		
}


#DEBUG use the old_ sub below for DFX_thesis data
sub load_clustering_dendrogram
{

	my $trace_file = shift;

	my (@cols, @merges, %clusters);
		
	if (! -e $trace_file)
		{ print "ERROR: clustering trace file not found\n"; exit; }
	
	open my $FCF, "<$trace_file";
	
	while (<$FCF>)

		{

		chomp;

		@cols = split DRCS, $_;

		push @merges, [@cols];
		
		}

	close $FCF;
	
	#print "total nodes in the dendrogram: " . scalar(keys %clusters) . "\n";
	
	return \@merges;

}


sub merges_list_to_hash_dendrogram
{

	my $list_ref = shift;
	my @merges = @{$list_ref};
	my %dendrogram;
	my ($c1, $c2, $p, $e);

	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e) = @{$_};

		# new leaf nodes
		if (! exists $dendrogram{$c1}) { $dendrogram{$c1} = []; }
		if (! exists $dendrogram{$c2}) { $dendrogram{$c2} = []; }

		$dendrogram{$p} = [$c1, $c2];
		delete $dendrogram{$c1}; delete $dendrogram{$c2};

		}
		
	return \%dendrogram;

}


#NOTE a "c" is used as a prefix for internal, i.e., non-leaf clusters
sub merges_list_to_newick_dendrogram
{

	my $list_ref = shift;
	my @merges = @{$list_ref};

	my ($c1, $c2, $p, $e, $l);
	my %newick_tree = ();
	
	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e, $l) = @{$_};

		foreach my $cluster($c1, $c2)
			{
			if (! exists $newick_tree{$cluster})
				{
				#$json_tree{$cluster} = "{id: \"$cluster\", name: \"$cluster\", data: {}, children: []}";
				$newick_tree{$cluster} = $cluster;				
				}
			}
			
		#$json_tree{$p} = "{id: \"$p\", name: \"c$p\", branch_length : \"$l\", data: {}, children: [$json_tree{$c1},$json_tree{$c2}]}"; 
		#delete($json_tree{$c1}); delete($json_tree{$c2}); 

		$newick_tree{$p} = "($newick_tree{$c1}:$l,$newick_tree{$c2}:$l)c$p"; 
		delete($newick_tree{$c1}); delete($newick_tree{$c2});
		
		}
		
=cut
	if (! %newick_tree)
		{
		$newick_tree{$cluster} = "$cluster";
		#$json_tree{$cluster} = "{id: \"$cluster\", name: \"c$cluster\", data: {}, children: []}";
		}
=cut	
	
	return $newick_tree{$p};
		
}


#NOTE a "c" is used as a prefix for internal, i.e., non-leaf clusters
sub merges_list_to_json_dendrogram
{

	my $list_ref = shift;
	my @merges = @{$list_ref};
	my ($cluster, $c1, $c2, $p, $e, $l);

	my %json_tree = ();
	
	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e, $l) = @{$_};

		foreach $cluster($c1, $c2)
			{
			if (! exists $json_tree{$cluster})
				{
				$json_tree{$cluster} = "{id: \"$cluster\", name: \"$cluster\", data: {}, children: []}";
				}
			}
			
		$json_tree{$p} = "{id: \"$p\", name: \"c$p\", branch_length : \"$l\", data: {}, children: [$json_tree{$c1},$json_tree{$c2}]}"; 
		delete($json_tree{$c1}); delete($json_tree{$c2}); 
		
		}
		
=cut		
	if (! %json_tree)
		{
		#$newick_tree{$cluster} = "$cluster";
		$json_tree{$cluster} = "{id: \"$cluster\", name: \"c$cluster\", data: {}, children: []}";
		}
=cut
		
	return $json_tree{$p};
		
}

		
#DEBUG this was using the old trace file format; now obsolete (see above comment)
sub old_load_clustering_dendrogram
{

	my $trace_file = shift;

	my (@cols, @merges, %clusters, $c, $c1, $p, $e);
	
	$c1 = 0;
	
	if (! -e $trace_file)
		{ print "ERROR: clustering trace file not found\n"; exit; }
	
	open my $FCF, "<$trace_file";
	
	while (<$FCF>)

		{

		chomp;

		@cols = split DRCS, $_;

		($c, $e, $p) = @cols[0, -3, -2];
		
		# first cluster of pair
		if (! $c1) { $c1 = $c; }

		else 
		
			{ 

			$clusters{$c1} = 1; $clusters{$c} = 1; $clusters{$p} = 1; 
			
			push @merges, [$c1, $c, $p, $e]; $c1 = 0; 
			
			}
		
		}

	close $FCF;
	
	#my $this_function = (caller(0))[3];
	#print "total nodes in the dendrogram: " . scalar(keys %clusters) . "\n";
	
	return \@merges;

}


sub build_random_dendrogram
{

	my ($list_ref, $first_parent_id, $parent_id_prefix) = @_;
	
	my @leaf_nodes = @{$list_ref};
	my %dendrogram = map { $_ => 1 } @leaf_nodes;
	my $p = $first_parent_id;
	my ($c1, $c2);
	
	my @merges = ();
	my $parents_introduced = 0;
	
	while (@leaf_nodes > 1)
		
		{
		
		$c1 = pop @leaf_nodes; $c2 = pop @leaf_nodes;
		
		push @merges, [$c1, $c2, $parent_id_prefix . $p];
		
		push @leaf_nodes, $parent_id_prefix . $p; 
		
		$p++;
		$parents_introduced++;
		
		}
		
	return (\@merges, $parents_introduced);

}


sub root_clustering_dendrogram
{

	my $list_ref = shift; 

	my %dendrogram = %{merges_list_to_hash_dendrogram($list_ref)};
		
	my @root_nodes = keys %dendrogram;
	
	#print "number of dendrogram root node(s): " . @root_nodes . "\n";

	#DEBUG do these new nodes need $e or $l values?
	my ($root_list_ref, $nodes) = build_random_dendrogram(\@root_nodes, FIRST_ARTIFICIAL_NODE_ID, "");
	
	my @merges = (@{$list_ref}, @{$root_list_ref});
	
	#DEBUGxxx
	#print "artifical nodes introduced to root the dendrogram: $nodes\n";
	
	# return the initial list of merges with 'artificial' merges added in case, 
	# and a list with the 'true' root node(s)
	return (\@merges, \@root_nodes);

}


sub add_dendrogram_branch_lengths
{

	my ($ref, $min_bl, $max_bl) = @_; 
	my @merges = @{$ref};

	my ($c1, $c2, $p, $e, $lowest_evalue, $branch_length);

	# find lowest merging evalue, as a scaling factor for branch length below
	$lowest_evalue = common::INFINITY;
	foreach (@merges)	
		{
		($c1, $c2, $p, $e) = @{$_};
		if ($p >= FIRST_ARTIFICIAL_NODE_ID) { last; }
		if ($e < $lowest_evalue) { $lowest_evalue = $e; }
		}
		
	my $branch_length_range = $max_bl - $min_bl;		
	
	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e) = @{$_};

		if ($p >= FIRST_ARTIFICIAL_NODE_ID)		
			{			
			# completely random: to signal these are artifical nodes inserted between
			# clusters so close to the root they don't show any similarity we chose the
			# highest 'real' branch length observed and double it
			$branch_length = $max_bl * 2;
			#DEBUGxxx
			$e = "-1";
			}
			
		else
		
			{					
			$branch_length = 
			$min_bl + ($branch_length_range - 
			($branch_length_range / common::log10($lowest_evalue)) * common::log10($e));			
			}

		#DEBUG could do this for symbolic reasons, to show we simply calculate 
		#DEBUG a symmetric branch length
		#$branch_length /= 2;
		$branch_length = sprintf "%.2f", $branch_length;
		
		$_ = [$c1, $c2, $p, $e, $branch_length];
		
		}
		
	return \@merges;
		
}
			

sub up_propagate_node_seqids
{

	my ($ref, $ref2) = @_;
	my %seq_ids_by_cluster = %{$ref};
	my @merges = @{$ref2};
	
	my ($c1, $c2, $p, $e);
	
	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e) = @{$_};
		
		#DEBUG
		#print "$c1 $c2 $p $e\n";

		$seq_ids_by_cluster{$p} = [@{$seq_ids_by_cluster{$c1}}, @{$seq_ids_by_cluster{$c2}}];		

		}
		
	return (\%seq_ids_by_cluster);

}

			
sub cut_clustering_dendrogram
{

	my ($list_ref, $granularity) = @_; 
	my @merges = @{$list_ref};

	my ($c1, $c2, $p, $e);

	my %dendrogram = ();
	my %clusters = ();
		
	my $flag = 0;
		
	foreach (@merges)
	
		{
		
		($c1, $c2, $p, $e) = @{$_};
		
		# new leaf nodes
		if (! exists $clusters{$c1}) { $dendrogram{$c1} = []; }
		if (! exists $clusters{$c2}) { $dendrogram{$c2} = []; }
		$clusters{$c1} = 1; $clusters{$c2} = 1; $clusters{$p} = 1;
								
		if ($flag || ($e > $granularity)) 
			{
			$flag = 1;
			next; 
			}
		
		$dendrogram{$p} = [$c1, $c2];
		delete $dendrogram{$c1}; delete $dendrogram{$c2};

		}
		
	my @root_nodes = keys %dendrogram;

	#print "number of clusters at granularity level $granularity: " . @root_nodes . "\n";

	return \@root_nodes;

}


# ARGS: merges list, omit nodes list (can be empty, usually these are all nodes
# that have been identified as children of the desired output tree's leaf nodes), 
# cluster ID of desired root node (to derive specific subtrees, 0 = dendrogram 
# root note), seq ids for each leaf node (cluster), where non-empty means we
# want individual sequences as leafs, i.e., 'unfold' the leaf clusters
sub filter_dendrogram
{

	my ($ref1, $ref2, $ref3, $ref4, $root_node) = @_; 
	my @merges = @{$ref1};
	my @omit_nodes = @{$ref2};
	
	my %seq_ids_by_node;
	if (! defined $ref3) { %seq_ids_by_node = (); }
	else { %seq_ids_by_node = %{$ref3} }
	
	my %seq_id_to_new_id;
	if (! defined $ref4) { %seq_id_to_new_id = (); }
	else { %seq_id_to_new_id = %{$ref4} }
		
	my ($cluster, $c1, $c2, $p, $e, $l, $i, $j);

	my $seqs_as_leafs = %seq_ids_by_node;
	my $seq_id_mapping = %seq_id_to_new_id;
	
	my %dendrogram;

	my $nodes = 0;
	my $omitted_nodes = 0;
	
	# to be sure it'll never be met below
	if (! $root_node) { $root_node = -1; }
	
	my @output_merges;
	
	my %map_to_child;
	
	foreach (@merges)
	
		{

		$ref1 = $_;
		
		($c1, $c2, $p, $e, $l) = @{$ref1};
		
		# omit (leaf) nodes as given in the passed list
		$i = 0;		
		for $cluster ($c1, $c2)
			{
			if (grep { $_ == $cluster } @omit_nodes) 
				{ $omitted_nodes++; $i = 1; }
			}
		if ($i) { next; }
		
		if ($seqs_as_leafs)			
			{
						
			$i = 0;	$j = 0;
			
			#DEBUG to get this right we have to map the parent node in these
			#DEBUG cases to either $c1 or $c2
			for $cluster ($c1, $c2)
				{
				#DEBUG was in separate loop
				if (exists $map_to_child{$cluster}) 
					{ $cluster = $map_to_child{$cluster}; }
				
				if (! @{$seq_ids_by_node{$cluster}})
					{
					$i++;
					$j = $cluster;
					}
				}
					
			if ($i) 
				{ 
				if ($i == 1) 
					{ 
					# omit (leaf) nodes where one of a sibling pair have no 
					# sequences in the list (of, e.g., annotated sequences),
					# by linking the parent to the child that does have seq's
					if ($j == $c1) { $map_to_child{$p} = $c2; } 
					else { $map_to_child{$p} = $c1; }
					}
				else
					{
					# omit both nodes if both have no sequences in the list
					}								
				
				$omitted_nodes += 2; next; 				
				}				
			}
		
		for $cluster ($c1, $c2)
			{		
						
			# insert a new leaf node in case
			if (! exists $dendrogram{$cluster}) 
				{ 
					
				$dendrogram{$cluster} = 1;
				
				if ($seqs_as_leafs)					
					{
					
					my @seqs_in_cluster = @{$seq_ids_by_node{$cluster}};
										
					if ($seq_id_mapping)
						{ 
						my %x = map { $_ => $seq_id_to_new_id{$_} } @seqs_in_cluster;
						@seqs_in_cluster = values %x; 
						}
																		
					if (! @seqs_in_cluster) { @seqs_in_cluster = ($cluster); }
					#else { $i = 1; }
					
					# build the fake sequence tree (random merging order)
					if (@seqs_in_cluster > 1)						
						
						{
					
						($ref2, $i) = build_random_dendrogram(\@seqs_in_cluster, 1, "$cluster\_");
						my @seq_merges = @{$ref2};
					
						# replace root node ID of sequence tree by cluster ID
						my ($c1, $c2, $p) = @{$seq_merges[-1]};
						$seq_merges[-1] = [$c1, $c2, $cluster];
						
						# add 0 values for E-value and branch length
						foreach (@seq_merges)
							{						
							($c1, $c2, $p) = @{$_};							
							#DEBUG
							#print "$cluster: $c1, $c2, $p\n";							
							push @output_merges, [$c1, $c2, $p, 0, 5];						
							}
							
						}
					
					else						
						
						{

						# change outer loop $c1 or $c2
						$cluster = $seqs_in_cluster[0];
						
						}
						
					}
								
				$nodes++;
				}
			}
						
		push @output_merges, [$c1, $c2, $p, $e, $l];						
		
		#DEBUG
		#print "$c1, $c2, $p, $e, $l\n";
		
		$dendrogram{$p} = 1;
		#delete $dendrogram{$c1}; delete $dendrogram{$c2};
		
		if ($p == $root_node) { last; }
		
		}

	my @trees = keys %dendrogram;

	print "leaf nodes in the dendrogram: $nodes\n";
	print "of which are root nodes: " . @trees . "\n";
		
	return \@output_merges;

}


sub retrieve_dendrogram_subtree_nodes
{

	my ($ref1, $ref2, $root_node) = @_; 
	my @merges = @{$ref1};
	my @omit_nodes = @{$ref2};

	my ($c1, $c2, $p, $e, $c, $i);

	my @subtree_nodes = ($root_node);
	my %child_nodes = ($root_node, 0);
		
	foreach (reverse @merges)
	
		{
		
		($c1, $c2, $p, $e) = @{$_};

		# omit child nodes as given in the passed list
		$i = 0;		
		for $c ($c1, $c2)
			{
			if (grep { $_ == $c } @omit_nodes) 
				{ $i = 1; }
			}
		if ($i) { next; }

		if (exists $child_nodes{$p}) 
			{ 
			$child_nodes{$c1} = 0;
			$child_nodes{$c2} = 0;
			delete $child_nodes{$p};
			push @subtree_nodes, $c1, $c2;
			}

		}
		
	return \@subtree_nodes;

}


sub generate_node_sibling_children_and_parent_hashes
{

	my $ref = shift; 
	my @merges = @{$ref};

	my ($c1, $c2, $p, $e);
	
	my %child_nodes_by_node = ();
	my %parent_node_by_node = ();
	my %sibling_node_by_node = ();
	
	foreach (@merges)
	
		{

		($c1, $c2, $p, $e) = @{$_};
		
		$sibling_node_by_node{$c1} = $c2; $sibling_node_by_node{$c2} = $c1; 
		$child_nodes_by_node{$p} = [$c1, $c2];
		$parent_node_by_node{$c1} = $p; $parent_node_by_node{$c2} = $p;
		
		}
		
	return (\%sibling_node_by_node, \%child_nodes_by_node, \%parent_node_by_node);
		
}
		

sub get_all_parents
{

	my ($cluster, $hash_ref) = @_;
	my %parents_hash = %{$hash_ref};
	my @parents = ();
	my @old_parents = ($cluster);
	my @new_parents = ();

	while (@old_parents)

		{

		@new_parents = ();
		
		foreach (@old_parents)

			{
			
			if (exists $parents_hash{$_})
			
				{
				
				push @new_parents, $parents_hash{$_}
				
				}
				
			}
				
		push @parents, @new_parents;	
			
		@old_parents = @new_parents;
		
		}

	return \@parents;
	
}


sub get_all_children
{

	my ($cluster, $hash_ref) = @_;
	my %children_hash = %{$hash_ref};
	my @children = ();
	my @old_children = ($cluster);
	my @new_children = ();

	while (@old_children)

		{

		@new_children = ();
		
		foreach (@old_children)

			{
			
			if (exists $children_hash{$_})
			
				{
				
				push @new_children, @{$children_hash{$_}}
				
				}
				
			}
				
		push @children, @new_children;	
			
		@old_children = @new_children;
		
		}

	return \@children;
	
}


sub get_all_leaf_children
{

	my ($cluster, $hash_ref) = @_;
	my %children_hash = %{$hash_ref};

	my @leaf_children = grep { ! exists $children_hash{$_} } 
						($cluster, @{get_all_children($cluster, $hash_ref)});

	return \@leaf_children;
	
}


sub remove_all_children
{

	my ($ref, $hash_ref) = @_;
	my @clusters = @{$ref};
	
	my %set = ();
	foreach my $cluster (@clusters)
		{
		#DEBUG could save child clusters for writing FASTAs below
		my @child_nodes = @{get_all_children($cluster, $hash_ref)};
		foreach (@child_nodes) { $set{$_} = 1; }
		}
		
	@clusters = grep { ! exists $set{$_} } @clusters;
	
	return (\@clusters, [keys %set]);
	
}


sub generate_cluster_mfasta_files
{

	my ($ref, $dir, $stderr_file, $children_hash_ref) = @_;
	
	my ($faa_file, $done, $exit_code);

	foreach my $cluster (@{$ref})

		{

		#print "$cluster\n";
		
		$faa_file = "$dir/$cluster.faa"; 
				
		foreach (@{funcclusters::get_all_leaf_children($cluster, $children_hash_ref)})
			{
			$exit_code = system("cat $starting_cluster_dir/$_\.faa >> $faa_file"); # 2>>$stderr_file");		
			if ($exit_code != 0) { last; } 
			}

		if ($exit_code != 0) 
			{ 
			print "ERROR $exit_code in compiling $faa_file!\n"; 
			unlink $faa_file;
			next;
			}
			
		$done++;
			
		}

	return $done;		

}


sub generate_hmmer_model_library
{

	my ($dir, $lib_file, $stderr_file) = @_;
	
	my @models = @{common::glob_files_without_path_and_extension($dir, "hmm")};
	
	# concat all models
	foreach (@models)
		{
		system("cat $dir/$_.hmm >> $lib_file");
		}

	#DEBUG redirect stderr?
	#DEBUG no --cpu option here yet
	#system("$hmmer_press_executable --cpu $hmmer_CPU_cores_used $lib_file"); # > /dev/null 2>>$stderr_file");
	system("$hmmer_press_executable $lib_file > /dev/null"); # > /dev/null 2>>$stderr_file");			
}


sub hmmer_search_tblout
{

	my ($hmm_file, $seq_db_file, $searchres_file, $stderr_file) = @_;

	#print "searching $hmm_file vs $seq_db_file...\n";

	my $exit_code = system("$hmmer_search_executable --max --cpu $hmmer_CPU_cores_used --tblout $searchres_file $hmm_file $seq_db_file > /dev/null 2>>$stderr_file");

}


sub hmmer_scan_tblout
{

	my ($query_seq_file, $hmm_db_file, $scanres_file, $stderr_file) = @_;
	
	my $exit_code = system("$hmmer_scan_executable --max --cpu $hmmer_CPU_cores_used --tblout $scanres_file $hmm_db_file $query_seq_file > /dev/null 2>>$stderr_file");

}


sub load_hmmer_search_output
{

	my $search_res_file = shift;
	
	open my $HF, "<$search_res_file"; my @results = <$HF>; close $HF;
	splice @results, 0, HMMER_SEARCH_OUTPUT_HEADER_LINES;
	chomp @results;
	return \@results;
	
}


#EOF
1;


