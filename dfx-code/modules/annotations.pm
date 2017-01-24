#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package annotations;

#TODO add more file (open) error checking!

use strict;

# the present module is used by scripts that reside in a direct child dir of the master dir, thus we have to search any other modules like this:
use lib "../modules";
use common;


our $VERSION = '1.00';
use base 'Exporter';

our @EXPORT = 

#DEBUG could add FTS to list and do a sed on other modules that use annotations::FTS
qw

(
		
	TERM2TYPE
	
);


our 

(

	$go_term_to_parents_file,
	$go_term_to_children_file,
	$go_term_to_name_file,
	$go_term_to_type_file,
	$go_mf_main_branch_terms_file
	
);


# constants
use constant 
{ 

	FUNC_TERM_SEPARATOR => "\;",

	TERM2TYPE_FILE_EXTENSION => "term2type",
	
	GO_OBO_XML_FILE_TERM_TAG => "<term>",

	GOA_COL_DB	=> 0,
	GOA_COL_ACC	=> 1,
	GOA_COL_QUALIFIER => 3,
	GOA_COL_TERM => 4,
	GOA_COL_SOURCE => 5,
	GOA_COL_EVIDENCE => 6,
	GOA_COL_EC => 7,
	GOA_COL_NAME => 9,
	GOA_COL_TAXON => 12,
	
	GOA_SOURCE_EC2GO => 3,
	GOA_SOURCE_SKW2GO => 37,
	GOA_SOURCE_TKW2GO => 38
	
};

# constant abbreviations
use constant 
{ 

	FTS => FUNC_TERM_SEPARATOR,

	TERM2TYPE => TERM2TYPE_FILE_EXTENSION
	
};

my %go_term_type_code = 
(
 
	"molecular_function" => "F", 
	"biological_process" => "P", 
	"cellular_component" => "C"

);


# these hashes must be populated and saved to the above files by calling go_init_hashes first
our %go_parents_by_node;
our %go_children_by_node;
our %go_term_name_by_id;
our %go_term_type_by_id;
our %go_mf_main_branch_terms;

#DEBUG make this switch accessable through dedicated subs (clear cache etc)
# to switch GO child/parent term hashing on/off
my $go_caching = 1;
my %go_parent_terms_cache = ();
my %go_child_terms_cache = ();

# used to exclude certain GO MF DAG branches in assessing cluster functional 
# conservation; as defined in config file (currently the 'binding' branch 
# including, amongst other things, multimerization); this set is populated in
# the init_ sub below
our @go_unreliable_mf_terms = ();

#DEBUG move to settings file
# protein binding, binding
use constant { GO_MF_ROOT_TERM => "GO:0003674" };

our	$ec_annotations_max_per_sequence = 1;
our	$ec_annotations_min_digits = 4;
our	$ec_annotations_max_digits = 4;
our	$ec_annotations_forbidden_digits = "-";


sub go_init_hash_file_names
{

	my $go_ontology_hash_file_set = pop @_;
	
	#DEBUG could make all extensions constants somewhere (only TERM2TYPE is used outside module)
	# these files cache hashes produced from the file above
	$go_term_to_parents_file = $go_ontology_hash_file_set . ".term2parents";
	$go_term_to_children_file = $go_ontology_hash_file_set . ".term2children";
	$go_term_to_name_file = $go_ontology_hash_file_set . ".term2name";
	$go_term_to_type_file = $go_ontology_hash_file_set . "." . TERM2TYPE;
	$go_mf_main_branch_terms_file = $go_ontology_hash_file_set . ".mfmainbranchterms";

}


# this is essential for many GO DAG related routines below
sub go_init_hashes
{

	# if set of hash files exists
	if (-e $go_term_to_parents_file)
		{


		%go_parents_by_node = %{common::load_hash_with_list_value_dif_separators($go_term_to_parents_file, DWCS, ";")};
		%go_children_by_node = %{common::load_hash_with_list_value_dif_separators($go_term_to_children_file, DWCS, ";")};
		%go_term_name_by_id = %{common::load_hash_with_scalar_value($go_term_to_name_file, DWCS)};
		%go_term_type_by_id = %{common::load_hash_with_scalar_value($go_term_to_type_file, DWCS)};
		# load hashes
		
		%go_mf_main_branch_terms = %{common::load_hash_with_list_value_dif_separators($go_mf_main_branch_terms_file, DWCS, ";")};
		}

	# else generate these files
	else
		{		
		
		#DEBUG this should never happen
		if (! -e $go_ontology_oboxml_file) { die "ERROR: $go_ontology_oboxml_file should exist at this point!\n"; }
		
		my ($ref1, $ref2, $ref3, $ref4) = go_load_oboxml_file($go_ontology_oboxml_file);
		%go_parents_by_node = %{$ref1};
		%go_children_by_node = %{$ref2};
		%go_term_name_by_id = %{$ref3};
		%go_term_type_by_id = %{$ref4};
		common::write_hash_with_list_value_dif_separators(\%go_parents_by_node, $go_term_to_parents_file, DWCS, ";");
		common::write_hash_with_list_value_dif_separators(\%go_children_by_node, $go_term_to_children_file, DWCS, ";");
		common::write_hash(\%go_term_name_by_id, $go_term_to_name_file, DWCS);
		common::write_hash(\%go_term_type_by_id, $go_term_to_type_file, DWCS);
		
		# the direct child branches of the molecular_function root term form the 
		# head nodes for the GO MF main branches; collect the terms for each main
		# branch
		foreach (@{$annotations::go_children_by_node{+GO_MF_ROOT_TERM}})
			{ 
			$go_mf_main_branch_terms{$_} = [$_, @{go_get_all_children($_)}];
			}		
		common::write_hash_with_list_value_dif_separators(\%go_mf_main_branch_terms, $go_mf_main_branch_terms_file, DWCS, ";");			
		}
		
	#DEBUG currently this is the 'binding' branch only
	# unreliable branches are defined in the annotations config file
	foreach (@go_unreliable_mf_branches) 
		{ push @go_unreliable_mf_terms, $_, @{go_get_all_children($_)}; }
	
	# deprecated terms are defined in the annotations config file
	# as a result, the root terms + the deprecated terms are ignored in all cases,
	# unlike the unreliable branch terms above, which are used if they are the 
	# only term type available for a sequence/cluster
	push @go_root_terms, @go_deprecated_terms; 
		
}


#NOTE this does not remove parental terms, that may st be found in GOA files
#NOTE for various reasons (e.g., stronger/other evidence for a parent term)
sub go_load_goa_file
{

	my ($in_file, $hash_ref, $list_ref) = @_;
	
	my %prot_id_by_acc = %{$hash_ref};
	my %sprot_prot_accs = map { $_ => 1 } @{$list_ref};
	
	open my $INF, "<$in_file";
	# ignore single line header ("!gaf-version: 2.0")
	my $i = <$INF>;

	#DEBUGxxx
	$| = 1;

	$i = 0;
	my %terms_by_prot_id;
	my %ecs_by_prot_id;
	while (<$INF>)
	
		{
	
		# there should be no comments apart from the header line
		if (/^!/) { next; }
		
		chomp;
		my @cols = split /\t/, $_;
		
		#print "$_\n";	
		
		my $db = $cols[GOA_COL_DB];
		# to be safe, even though IPI has been discontinued
		if ($db ne "UniProtKB") { next; } 
		
		my $acc = $cols[GOA_COL_ACC];
		
		# can we map it to G3D and is it of OK quality (see above)?
		if (! exists $prot_id_by_acc{$acc}) { next; }
					
		my $prot_id = $prot_id_by_acc{$acc};
		
		#my ($name, $taxon_id) = @cols[GOA_COL_NAME, GOA_COL_TAXON];
		# chop the 'taxon:' prefix
		#$taxon_id = substr $taxon_id, 6;
		#$name_by_prot_id{$prot_id} = $name;
		#$taxid_by_prot_id{$prot_id} = $taxon_id;
		
		my $evidence = $cols[GOA_COL_EVIDENCE];
		
		my $is_hq_anno = 0;	
		my $ec = "none";

		#NOTE "The Qualifier column is used for flags that modify the interpretation of an
		#NOTE annotation. Allowable values are NOT, contributes_to, and colocalizes_with."
		my $qualifier = $cols[GOA_COL_QUALIFIER];

		#NOTE we ignore the above cases for now
		if ($qualifier) { next; }
		
		# non-IEA
		if ($evidence ne "IEA") 
			
			{ 
			
			$is_hq_anno = 1; 
			
			}
		
		# is it in SwissProt?
		elsif (exists $sprot_prot_accs{$acc})
				
			{
			
			# chop GO_REF: prefix
			my $source = substr $cols[GOA_COL_SOURCE], 7;
			
			# EC2GO
			if ($source == GOA_SOURCE_EC2GO)
				{
				# chop EC: prefix
				$ec = substr $cols[GOA_COL_EC], 3;
				
				$ecs_by_prot_id{$prot_id}{$ec} = 1;
							
				$is_hq_anno = 1;
				
				}
			
			#DEBUGxxx make constants somewhere in a GO anno module or in annotations.pm!
			# UniProtKB-KW_2GO (was: SP_KW_2GO, see start of code)
			# was: reference code 4, now 37 and 38
			elsif (($source == GOA_SOURCE_SKW2GO) ||
				   ($source == GOA_SOURCE_TKW2GO))
				{
					
				$is_hq_anno = 1;				
				
				}
		
			}
			
		# is it a high-quality GO annotation? (see above)
		if (! $is_hq_anno) { next; }
		
		my $term = $cols[GOA_COL_TERM];
		
		$terms_by_prot_id{$prot_id}{$term} = 1;
		
		$i++;

		#if ($i == 100) { last; }

		#DEBUG progress bar
		#if (keys(%terms_by_prot_id) % 1000 == 0) { print keys(%terms_by_prot_id) . "\n"; }
		if ($i % 10000 == 0) { print "."; }
		
		#print "$prot_id $acc $term $name $taxon_id\n";
		
		}
	close $INF;

	#DEBUG progress bar newline
	print ".\n";
	$| = 0;
		
	return (\%terms_by_prot_id, \%ecs_by_prot_id);

}


sub go_terms_to_str
{

	return join FTS, @_;

}


sub go_str_to_terms
{

	return split FTS, shift;

}


sub go_filter_terms
{

	my $term_types = shift;
	my $ref = shift; 
	my %invalid_terms = map { $_ => 1 } @{$ref};
	$ref = shift; 
	my @terms = @{$ref};

	my @valid_type_terms = ();
	my @invalid_type_terms = ();

	my ($type_terms, $valid_type_terms) = (0, 0);

	foreach my $term (@terms) 

		{

		if (! exists $go_term_type_by_id{$term}) 
			{ 
			#DEBUG
			print "WARNING unknown GO term: $term\n"; 
			next; 
			}
		
		if ($go_term_type_by_id{$term} !~ $term_types) { next; }

		$type_terms++;

		if (exists $invalid_terms{$term}) 
			{ push @invalid_type_terms, $term; }
		else
			{ push @valid_type_terms, $term; }

		}

	$valid_type_terms = @valid_type_terms;

	return ($type_terms, $valid_type_terms, \@valid_type_terms, \@invalid_type_terms); 

}


sub go_load_oboxml_file
{

	my $fn = shift;

	my $term;
	my ($obsolete, $total) = (0, 0);

	my %go_parents_by_node = ();
	my %go_children_by_node = ();
	my %go_term_name_by_id = ();
	my %go_term_type_by_id = ();

	#print "parsing OBO XML file $fn...\n";

	my $OXF;	
	if (! open $OXF, "<$fn") 
		{ print "ERROR: cannot open GO OBO XML file $fn!\n"; exit 1; }

	while (<$OXF>)

		{

		chomp; #print "$_\n";
		s/\s+//;
		# create term node
		if (m/^<id>(GO:\d.*)<\/id>/) { $term = $1; $go_parents_by_node{$term} = []; $total++; }
		# link to parent node
		elsif (m/^<is_a>(GO:\d.*)<\/is_a>/) { push @{$go_parents_by_node{$term}}, $1; if (! exists $go_children_by_node{$1}) { $go_children_by_node{$1} = []; } push @{$go_children_by_node{$1}}, $term; }
		# map term id to term type
		elsif (m/^<namespace>(.*)<\/namespace>/) { if (! exists $go_term_type_by_id{$term}) { $go_term_type_by_id{$term} = $go_term_type_code{$1}; } }
		# map term id to term name
		elsif (m/^<name>(.*)<\/name>/) { if (! exists $go_term_name_by_id{$term}) { $go_term_name_by_id{$term} = $1; } }
		# check if obsolete
		elsif (m/^<is_obsolete>1/) { $obsolete++; delete $go_parents_by_node{$term}; delete $go_term_name_by_id{$term}; }

		}

	close $OXF;

	$total -= $obsolete;
	
	#print "$total terms hashed.\n";
	#print "$obsolete obsolete terms ignored.\n";

	return (\%go_parents_by_node, \%go_children_by_node, \%go_term_name_by_id, \%go_term_type_by_id);
	
}


#DEBUG no longer used
sub go_write_term_name_and_id_file
{

	my $fn = shift;

	my $TIF;	
	if (! open $TIF, ">$fn") 
		{ print "ERROR: cannot write GO term IDs file $fn!\n"; exit 1; }
	foreach my $term(sort { $a ne $b } keys %go_term_name_by_id)	
		{	
		print $TIF "$term\t$go_term_name_by_id{$term}\t$go_term_type_by_id{$term}\n";	
		}
	close $TIF;

}


#DEBUG no longer used (was: to be completed)
sub go_load_term_name_and_id_file
{

	my $fn = shift;

	%go_term_name_by_id = ();
	%go_term_type_by_id = ();

	my $TIF;	
	if (! open $TIF, "<$fn") 
		{ print "ERROR: cannot open GO term IDs file $fn!\n"; exit 1; }
	while (<$TIF>)
		{
		#print $OUF "$term\t$go_term_name_by_id{$term}\t$go_term_type_by_id{$term}\n";	
		}
	close $TIF;

}


sub go_get_all_parents
{

	my $term = shift;

	if ($go_caching && exists $go_parent_terms_cache{$term})
		{ return $go_parent_terms_cache{$term}; }

	my $original_term = $term;
		
	my @parents;
	my @all_parents = ();
	my %all_parents = ();
	my $parent_term;
	
	my $parents_left = 1;

	while ($parents_left)

		{

		if (exists $go_parents_by_node{$term})

			{

			@parents = @{$go_parents_by_node{$term}};

			foreach $parent_term (@parents)
				{
				if (! exists $all_parents{$parent_term})
					{
					$all_parents{$parent_term} = 0;
					}
				}

			}

		$parents_left = 0;

		foreach $parent_term (keys %all_parents)

			{

			if (! $all_parents{$parent_term}) 
				{ 
				push @all_parents, $parent_term;
				$all_parents{$parent_term} = 1;
				$parents_left = 1;

				$term = $parent_term;
				last;
				}

			}

		}

	if ($go_caching)
		{ $go_parent_terms_cache{$original_term} = \@all_parents; }
		
	return \@all_parents;

}


sub go_get_all_children
{

	my $term = shift;

	if ($go_caching && exists $go_child_terms_cache{$term})
		{ return $go_child_terms_cache{$term}; }

	my $original_term = $term;
		
	my @children;
	my @all_children = ();
	my %all_children = ();
	my $child_term;

	my $children_left = 1;

	while ($children_left)

		{

		if (exists $go_children_by_node{$term})

			{

			@children = @{$go_children_by_node{$term}};

			foreach $child_term (@children)
				{
				if (! exists $all_children{$child_term})
					{

					$all_children{$child_term} = 0;
					}
				}

			}

		$children_left = 0;

		foreach $child_term (keys %all_children)

			{

			if (! $all_children{$child_term}) 
				{ 
				push @all_children, $child_term;
				$all_children{$child_term} = 1;
				$children_left = 1;
				$term = $child_term;
				last;
				}

			}

		}

	if ($go_caching)
		{ $go_child_terms_cache{$original_term} = \@all_children; }
		
	return \@all_children;

}


sub go_get_all_direct_siblings
{

	my $term = shift;

	my %set = ();

	# get direct parents
	foreach (@{$go_parents_by_node{$term}})

		{

		# get direct children
		foreach (@{$go_children_by_node{$_}}) { $set{$_} = 1; }

		}

	my @all_siblings = keys %set;

	@all_siblings = grep { $_ ne $term } @all_siblings;
	
	return \@all_siblings;

}


sub go_get_common_parents
{

	my $ref = shift;
	my @terms = @{$ref};
	my (@parents, %parents);
	my @common_parents = ();
	
	foreach my $term (@terms)

		{

		@parents = @{go_get_all_parents($term)};
		%parents = map { $_ => 1 } @parents;

		if (! @common_parents) { @common_parents = @parents; }
		else { @common_parents = grep { exists $parents{$_} } @common_parents; }
		
		}

	return \@common_parents;

}


# to which MF main branches do the terms in a set belong?
sub go_get_mf_main_branches
{

	my $ref = shift;
	my @terms = @{$ref};
	my @mf_main_branch_terms;
	
	my %mf_main_branches = 
	map { $_ => 0 } keys %annotations::go_mf_main_branch_terms;
	
	@mf_main_branch_terms = sort grep { exists $go_mf_main_branch_terms{$_} }
							@{go_get_all_parents_termlist(\@terms)}, @terms;

	return \@mf_main_branch_terms;

}


# which is the most specific parent term shared by all in a set?
sub go_get_most_specific_common_parent
{

	my $ref = shift;
	my @terms = @{$ref};

	if (@terms == 1) { return $terms[0]; }
	

	my @parent_nodes = @{annotations::go_get_common_parents(\@terms)};
	# remove all parents so that only the most specific common parent remains
	@parent_nodes = @{annotations::go_remove_any_parents(\@parent_nodes)};
	# this is the last common ancestor term in this branch

	return $parent_nodes[0];
	
}


sub go_get_common_parents_from_set
{

	my $ref = shift;
	my @terms = @{$ref};
	$ref = shift;
	my %set = map { $_ => 0 } @{$ref};
	
	my (@parents, %parents);
	my @common_parents = ();
	
	foreach my $term (@terms)

		{

		@parents = @{go_get_all_parents($term)};
		@parents = grep { exists $set{$_} } @parents;
		%parents = map { $_ => 1 } @parents;
		
		if (! @common_parents) { @common_parents = @parents; }
		else { @common_parents = grep { exists $parents{$_} } @common_parents; }
		
		}

	return \@common_parents;

}


sub go_get_most_specific_common_parent_from_set
{

	my $ref = shift;
	my @terms = @{$ref};
	$ref = shift;
	my @set = @{$ref};

	my @parent_nodes = @{annotations::go_get_common_parents_from_set(\@terms, \@set)};
	# remove all parents so that only the most specific common parent remains
	@parent_nodes = @{annotations::go_remove_any_parents(\@parent_nodes)};
	# this is the last common ancestor term in this branch

	return $parent_nodes[0];
	
}


sub go_get_all_parents_termlist
{

	my $ref = shift;
	my @terms = @{$ref};
	my %all_parents = ();

	foreach my $term (@terms)

		{

		foreach (@{annotations::go_get_all_parents($term)}) { $all_parents{$_}++; }

		}

	my @all_parents = keys %all_parents;
	
	return \@all_parents;

}


sub go_get_all_children_termlist
{

	my $ref = shift;
	my @terms = @{$ref};
	my %all_children = ();

	foreach my $term (@terms)

		{

		foreach (@{annotations::go_get_all_children($term)}) { $all_children{$_}++; }

		}

	my @all_children = keys %all_children;
	
	return \@all_children;

}

#DEBUG this should keep the initial order if the input term set is sorted?
sub go_remove_any_parents
{

	my $ref = shift;
	my @terms = @{$ref};
	
	my %all_parents = map { $_ => 0 } @{go_get_all_parents_termlist(\@terms)};
	
	@terms = grep { ! exists $all_parents{$_} } @terms;
		
	return \@terms;

}


sub go_remove_any_children
{

	my $ref = shift;
	my @terms = @{$ref};
		
	my %all_children = map { $_ => 0 } @{go_get_all_children_termlist(\@terms)};

	@terms = grep { ! exists $all_children{$_} } @terms;
		
	return \@terms;

}


sub go_remove_and_return_any_parents
{

	my $ref = shift;
	my @terms = @{$ref};
	my @parents;

	#DEBUG not efficient since this internally converts hash to list
	my %all_parents = map { $_ => 0 } @{go_get_all_parents_termlist(\@terms)};
		
	@parents = grep { exists $all_parents{$_} } @terms;
	@terms = grep { ! exists $all_parents{$_} } @terms;
	
	return (\@terms, \@parents);

}


#DEBUG remove/revise all below
# ============================== remove/revise ==================================

sub go_write_parents_file
{
	
	my $fn = shift;
	
	my @all_parents;
	my $all_parents;

	my $PTF;	
	if (! open $PTF, ">$fn") 
		{ print "ERROR: cannot write GO term parents file $fn!\n"; exit 1; }
	foreach my $term(sort { $a ne $b } keys %go_parents_by_node)
		{
		@all_parents = @{go_get_all_parents($term)};
		if (!@all_parents) { $all_parents = "none"; } 
		else 
			{ 
			@all_parents = sort { $a ne $b } @all_parents; 
			$all_parents = join FTS, @all_parents; 
			}
		print $PTF "$term\t$all_parents\n";	
		}
	close $PTF;

}


sub go_load_parents_file
{

	my $fn = shift;
	my %go_parents_by_node = ();
	
	my @all_parents;
	my $all_parents;

	my ($term, $parents, $parent);
	
	my $PTF;	
	if (! open $PTF, "<$fn") 
		{ print "ERROR: cannot write GO term parents file $fn!\n"; exit 1; }
	while (<$PTF>)
		{
		chomp;
		($term, $parents) = split common::DRCS;
		if ($parents eq "none") { next; }
		@all_parents = split FTS, $parents;
		$go_parents_by_node{$term} = [];
		foreach (@all_parents) 
			{ 
			#s/GO://; 
			push @{$go_parents_by_node{$term}}, $_; 
			}
		}
	close $PTF;

	return \%go_parents_by_node;

}


sub load_simple_ec_anno_file
{

	#DEBUG remove EC args and use the default settings from common.pm
	my ($anno_file, $min_ec_digits, $forbidden_ec_digits, $max_ecs_per_sequence) = @_;

	my (%annotations, %histo_different_annotations) = ((), ());

	my (@ecs, $ecs, $ec, @ec_digits);
	
	my %anno_by_seqid = %{common::load_hash_with_scalar_value($anno_file, DRCS)};
	
	foreach my $seq_id (keys %anno_by_seqid)
	
		{
	
		$ecs = $anno_by_seqid{$seq_id};
	
		if ($ecs eq "none") { next; }
		
		@ecs = split FTS, $ecs;
		
		# discard seqs with more than one EC for now
		if (@ecs > $max_ecs_per_sequence) { next; }
		
		my @anno_terms = ();

		foreach $ec(@ecs)

			{

			# EC digits
			@ec_digits = split /\./, $ec;

			# EC filtering		
			if ((@ec_digits < $min_ec_digits) or ($ec =~ /$forbidden_ec_digits/)) { next; }
		
			push @anno_terms, $ec;

			}

		@ecs = sort @anno_terms;

		$ecs = join FTS, @ecs;

		$annotations{$seq_id} = $ecs;
		
		$histo_different_annotations{$ecs}++;
              
		}

	if (keys %histo_different_annotations < 2) { print "WARNING: less than two different annotations!\n"; %annotations = (); }

	return \%annotations;

}


sub load_simple_go_anno_file
{

	my ($anno_file, $max_terms_per_sequence) = @_;

	my (%annotations, %histo_different_annotations) = ((), ());
	
	my ($gos, @gos);

	my %anno_by_seqid = %{common::load_hash_with_scalar_value($anno_file, DRCS)};
	
	foreach my $seq_id (keys %anno_by_seqid)
	
		{
	
		print "$seq_id\n";

		$gos = $anno_by_seqid{$seq_id};
	
		if ($gos eq "none") { next; }
		
		@gos = split FTS, $gos;
		
		if (@gos > $max_terms_per_sequence) { next; }

		@gos = sort @gos;

		$gos = join FTS, @gos;

		$annotations{$seq_id} = $gos;
		
		$histo_different_annotations{$gos}++;
              
		}
	
	if (keys %histo_different_annotations < 2) { print "WARNING: less than two different annotations!\n"; %annotations = (); }

	return \%annotations;

}


=cut
DEBUG not currently used
this hashes all accepted GO terms of certain type(s) (e.g. "F" for molecular 
function or "F|P" for this or biological process); only the terms loaded here 
will be used throughout so pre-filtering this file with e.g. grep is a way to 
ignore certain terms (e.g. all "binding" ones); note that this file must never 
be more recent than the OBO XML ontology file used, otherwise it could contain 
novel terms not defined in the latter!
=cut
sub go_load_terms
{
	
	my ($fn, $go_term_types) = @_;

	my @go_terms = ();
	my ($term, $name, $type);
	
	my $GTF;	
	if (! open $GTF, "<$fn") 
		{ print "ERROR: cannot open GO term ID file $fn!\n"; exit 1; }
	while (<$GTF>) 
		{
		# skip any header/commentary lines (such are found in official GO term def text files)
		if (/^\!/) { next; }
		chomp; ($term, $name, $type) = split common::DWCS;
		if ($type =~ m/$go_term_types/) { push @go_terms, $term; }
		}
	close $GTF;

	return \@go_terms;

}


sub load_anno_seq_names
{
	
	my $fn = shift;

	my %anno_seq_names = ();
	my ($seq_id, $name);

	my $SNF;	
	if (! open $SNF, "<$fn") 
		{ print "ERROR: cannot open sequence name file $fn!\n"; exit 1; }
	while (<$SNF>) 
		{
		chomp; ($seq_id, $name) = split common::DWCS;
		$anno_seq_names{$seq_id} = $name;
		}
	close $SNF;

	return \%anno_seq_names;

}


sub load_generic_anno_file
{

	#my ($anno_file, $min_ec_digits, $forbidden_ec_digits, $max_ecs_per_sequence, $go_accepted_terms_file, $go_accepted_term_types, $transfer_ec_by_go, $transfer_go_by_ec) = @_;
	my ($fn, $go_accepted_term_types) = @_;
	
	#DEBUG move to common or localpart modules; change for dfx_2010
	my ($ec_col, $go_col) = (2, 1);
	
	# for EC filtering overwrite the following global vars of this module in 
	# calling script in case:
	# $ec_annotations_max_per_sequence $ec_annotations_forbidden_digits
	# $ec_annotations_min_digits $ec_annotations_max_digits
	
	#DEBUG these used to be parameters to this sub;
	#DEBUG turned off until further thinking, there are problems with this
	#DEBUG for example, a coarse term associated with a sequence that also has
	#DEBUG a 4-level EC should not lead to another sequence inheriting the EC!
	my ($transfer_ec_by_go, $transfer_go_by_ec) = (0, 0);
	
	my (%go_annotations, %ec_annotations, %go_counts, %histo_go_terms_per_seq, %histo_ec_numbers_per_seq) = ((), (), (), (), (), ());

	my @non_ec_seqs = ();
	
	my %ec_numbers_by_go_mf_terms = ();
	
	my %union_of_go_terms_associated_with_ec = ();

	my ($anno_seqs, $ec_seqs, $ec_seqs_with_more_than_one, $go_seqs, $go_seqs_no_terms) = (0, 0, 0, 0, 0);
	
	my (@filtered, @cols);

	my (@anno_go_terms, @anno_ec_numbers);
	my ($anno_go_terms, $anno_ec_numbers);
	
	my ($seq_id, $anno_type);
	
	my (@ec_associated_go_terms, @all_terms);
	
	my ($go_transfer_by_ec_cases, $ec_transfer_by_go_cases) = (0, 0);

	my $ANF;	
	if (! open $ANF, "<$fn") 
		{ print "ERROR: cannot open annotations file $fn!\n"; exit 1; }
	while (<$ANF>)
	
		{
		
		chomp;
		
		@cols = split common::DWCS;
		
		($seq_id, $anno_ec_numbers, $anno_go_terms) = 
		@cols[0, $ec_col, $go_col];
		
		# there's no whitespace in our annotation files, but to be safe
		$anno_go_terms =~ s/\s+//g;
		$anno_ec_numbers =~ s/\s+//g;
		
		$anno_type = "none";
		
		if ($anno_go_terms ne "none") 
		
			{ 
			
			$anno_type = "GO";
			
			# get all GO terms for that sequence
			@anno_go_terms = split FTS, $anno_go_terms;

			#DEBUGxxx if a sequence only has root annotation(s) that doesn't count as annotated
			#DEBUG speed? could do this in calling scripts instead
			my ($all_terms_count, $valid_terms_count, $kept_ref, $filtered_ref) =
			annotations::go_filter_terms($go_accepted_term_types, \@go_root_terms, \@anno_go_terms);
			@anno_go_terms = @{$kept_ref};									
			# above filtering can leave no terms at times
			if (! @anno_go_terms) { $anno_go_terms = "none"; } 
			else 
				{ 
		
				#DEBUG technically OK, but for family identification parent terms
				#DEBUG that were - for whatever reason - kept annotated by the GO
				#DEBUG people can potentially provide hints; let's hope most of
				#DEBUG these cases are when different related terms have different
				#DEBUG evidence codes associated with them (of those we include in
				#DEBUG our annotation files)
				# we remove any parental terms and keep only the most specific annotations
				@anno_go_terms = @{go_remove_any_parents(\@anno_go_terms)};

				@anno_go_terms = sort @anno_go_terms;

				$anno_go_terms = join FTS, @anno_go_terms;
				$go_annotations{$seq_id} = $anno_go_terms;

				}
		
			#NOTE the annotation files only contain EC annotations were there
			#NOTE is also at least one GO term assigned
			if ($anno_ec_numbers ne "none")

				{
					
				$anno_type = "GO+EC";

				@anno_ec_numbers = split FTS, $anno_ec_numbers;

				if (@anno_ec_numbers > $ec_annotations_max_per_sequence) 
					{ $ec_seqs_with_more_than_one++; @anno_ec_numbers = (); }

				@filtered = ();
				foreach my $ec (@anno_ec_numbers)

					{

					# EC digits
					@cols = split /\./, $ec;

					# filtering for digit number
					if (@cols < $ec_annotations_min_digits)
						{ next; }
					elsif (@cols > $ec_annotations_max_digits)
						{ $ec = join "\.", @cols[0..$ec_annotations_max_digits-1]; }
						
					# filtering for forbidden digits (normally the last digit)
					if ($ec =~ m/$ec_annotations_forbidden_digits/)
						{ next; }

					push @filtered, $ec;
			
					}

				@anno_ec_numbers = sort @filtered;

				# there could be none left after filtering above
				if (@anno_ec_numbers) 

					{ 

					$anno_ec_numbers = join FTS, @anno_ec_numbers; 
					
					$ec_annotations{$seq_id} = $anno_ec_numbers;

					#DEBUG
					if ($transfer_ec_by_go || $transfer_go_by_ec)
						{
					
						# DEBUG could look at >1 EC cases more specifically too
						# DEBUG it's not trivial to map between multiple ECs and GO MFs
						if ((@anno_go_terms) && (@anno_ec_numbers == 1))

							{

							#DEBUG we may wanna filter out the MF root term too?
							# get MF term sets 
							my ($all_terms_count, $valid_terms_count, $ref1, $ref2) =
							annotations::go_filter_terms("F", \@go_unreliable_mf_terms, \@anno_go_terms);
							@anno_go_terms = @{$ref1};
							
							if (@anno_go_terms)
								
								{
								
								# EC numbers indexed by GO terms; different term sets for the same EC
								# are possible here
								$anno_go_terms = join FTS, @anno_go_terms;
							
								if (! exists $ec_numbers_by_go_mf_terms{$anno_go_terms}) 
									{ 
									$ec_numbers_by_go_mf_terms{$anno_go_terms} = $anno_ec_numbers; 
									} 
								
								if (! exists $union_of_go_terms_associated_with_ec{$anno_ec_numbers}) 
									{ 
									$union_of_go_terms_associated_with_ec{$anno_ec_numbers} = [@anno_go_terms]; 
									}					
								else 					
									{													
									@ec_associated_go_terms = @{$union_of_go_terms_associated_with_ec{$anno_ec_numbers}};
									@anno_go_terms = @{common::sorted_union(\@ec_associated_go_terms, \@anno_go_terms)};
									$union_of_go_terms_associated_with_ec{$anno_ec_numbers} = [@anno_go_terms];
									}
									
								}

							} 
							   
						}

					}
					
				}
				
			else 
				
				{ push @non_ec_seqs, $seq_id; }
					

			}
			
		else
		
			{ $go_seqs_no_terms++; }
			
		# no anno at all - should never happen with our kind of annotation files
		if ($anno_type ne "none") { $anno_seqs++; }

		#DEBUG
		#if ($anno_seqs % 100000 == 0) { print "$anno_seqs\n"; }
		
		}		
	close $ANF;
	
	# GO transfer by EC annotations
	# assign the union of GO terms found for a given EC to all sequences with 
	# this EC

	my $ecs; #@ecs;

	#DEBUG currently switched off, see start of sub
	if ($transfer_go_by_ec)

		{

		#print "transferring GO MF by EC annotations\n";
		
		foreach $seq_id (keys %go_annotations)
		
			{
			
			if (! exists $ec_annotations{$seq_id}) { next; }
			
			#@ecs = split FTS, $ec_annotations{$seq_id};

			$ecs = $ec_annotations{$seq_id};
			
			@anno_go_terms = split FTS, $go_annotations{$seq_id};
			
			my %orig_anno_go_terms = map { $_ => 0 } @anno_go_terms;

			#DEBUG treat combinations of ECs as a single annotation for now
			foreach my $ec ($ecs) #(@ecs)
			
				{
			
				if (! exists $union_of_go_terms_associated_with_ec{$ec}) { next; }

				@ec_associated_go_terms = @{$union_of_go_terms_associated_with_ec{$ec}};

				@filtered = grep { ! exists $orig_anno_go_terms{$_} } @ec_associated_go_terms;

				if (@filtered)
				
					{
				
					@anno_go_terms = @{common::sorted_union(\@ec_associated_go_terms, \@anno_go_terms)};
					@anno_go_terms = @{go_remove_any_parents(\@anno_go_terms)};

					@filtered = grep { ! exists $orig_anno_go_terms{$_} } @anno_go_terms;
				
					if (@filtered)
						
						{
					
						$anno_go_terms = join FTS, @anno_go_terms;
						$go_annotations{$seq_id} = $anno_go_terms;
						$go_transfer_by_ec_cases++;	
						
						#print "$seq_id (@anno_go_terms) inherits @filtered via $ec!\n"; 
						
						}
					
					}
				
				}
				
			}
			
		#print "$go_transfer_by_ec_cases transferred.\n";

		}

	# DEBUG this is very slow and does not produce many transfers (none most of the time?)
	# consider this an experimental feature
	# EC transfer by GO annotations
	# transfer EC if GO terms are same or a superset of a sequence with EC annotation

	#DEBUG currently switched off, see start of sub
	if ($transfer_ec_by_go)

		{
		
		#print "transferring EC by GO MF annotations\n";

		foreach $seq_id (@non_ec_seqs)

			{

			#DEBUG this should never be the case with our kind of annotation files
			if (! exists $go_annotations{$seq_id}) 
				{ print "WARNING: $seq_id has no annotation at all!\n"; next; }

			@anno_go_terms = split FTS, $go_annotations{$seq_id};
			
			foreach my $enz_go_terms (keys %ec_numbers_by_go_mf_terms)
				
				{

				@ec_associated_go_terms = split FTS, $enz_go_terms;
				
				if (common::is_subset(\@ec_associated_go_terms, \@anno_go_terms))

					{ 

					$ec_annotations{$seq_id} = $ec_numbers_by_go_mf_terms{$enz_go_terms}; 

					$ec_transfer_by_go_cases++;

					#print "$seq_id (@anno_go_terms) inherits $ec_annotations{$seq_id} via $enz_go_terms!\n"; 
					
					last;
					
					}

				}

			}
			
		#print "$ec_transfer_by_go_cases transferred.\n";
	
		}
	

	#DEBUG we probably overdo the stats thing here a bit

	foreach $seq_id (keys %go_annotations) { $go_seqs++; $histo_go_terms_per_seq{$go_annotations{$seq_id}}++; }
	foreach $seq_id (keys %ec_annotations) { $ec_seqs++; $histo_ec_numbers_per_seq{$ec_annotations{$seq_id}}++; }

	my $distinct_gos = keys %histo_go_terms_per_seq; my $distinct_ecs = keys %histo_ec_numbers_per_seq; my $go_only_seqs = $go_seqs - $ec_seqs;
	
	#print "total, GO, EC, GO_only, distinct_GOs, distinct_ECs, GO_no_terms, EC_>_1, GO_to_EC, EC_to_GO: $anno_seqs, $go_seqs, $ec_seqs, $go_only_seqs, $distinct_gos, $distinct_ecs, $go_seqs_no_terms, $ec_seqs_with_more_than_one\n";
	
	if ($distinct_gos < 2) { #print "WARNING: <2 different GO annotations!\n"; 
	%go_annotations = (); }
	if ($distinct_ecs < 2) { #print "WARNING: <2 different EC annotations!\n"; 
	%ec_annotations = (); }

	#foreach(sort {$a <=> $b} keys %histo_go_terms_per_seq) { print "$_ $histo_go_terms_per_seq{$_}\n"; }	
	#print "\n";

	return (\%go_annotations, \%ec_annotations);

}


#NOTE this converts from domain to protein id in case
#NOTE this ignores any sequences without annotations
sub go_count_sequence_set_terms
{

	my $ref = shift;
	my @anno_seq_ids = @{$ref};
	$ref = shift;
	my %terms_by_prot_id = %{$ref};
	
	my @anno_prot_seq_ids = grep { exists $terms_by_prot_id{$_} }
							map { common::trunc_seq_header($_) }
							@anno_seq_ids;
	
	my %all_term_counts = (); 

	foreach my $prot_seq_id (@anno_prot_seq_ids)		
		{
		
		my $terms = $terms_by_prot_id{$prot_seq_id};
		my @prot_seq_terms = split FTS, $terms;				
		foreach (@prot_seq_terms) { $all_term_counts{$_}++; }
		
		}
			
	return \%all_term_counts;
	
}


#NOTE this converts from domain to protein id in case
#NOTE this ignores any sequences without annotations
sub go_count_sequence_set_terms_and_parents
{

	my $ref = shift;
	my @anno_seq_ids = @{$ref};
	$ref = shift;
	my %terms_by_prot_id = %{$ref};
	
	my @anno_prot_seq_ids = grep { exists $terms_by_prot_id{$_} }
							map { common::trunc_seq_header($_) }
							@anno_seq_ids;
	
	my %all_term_counts = (); 

	foreach my $prot_seq_id (@anno_prot_seq_ids)		
		{
		
		my $terms = $terms_by_prot_id{$prot_seq_id};
		my @terms = split FTS, $terms;				
		#DEBUG always add root terms to be safe; they would be missing
		#DEBUG in case @terms was empty for a given sequence
		my %set = map { $_ => 1 } 
		(@go_root_terms, @terms, @{go_get_all_parents_termlist(\@terms)});
		map { $all_term_counts{$_}++; } keys %set;
		
		}
			
	return \%all_term_counts;
	
}


#EOF
1;
