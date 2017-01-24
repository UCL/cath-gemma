#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package taxonomy;

#TODO use caching in these subs, as for GO DAG lookups in annotations.pm

use strict;

# the present module is used by scripts that reside in a direct child dir of the master dir, thus we have to search any other modules like this:
use lib "../modules";
use common;


use constant 

{

#UniProtKB taxonomy IDs

	# artifical meta-root
	ALL_TAXON => -1,
	
	# cellular organisms root
	ORGANISMS_TAXON => 131567,
	BACTERIA_TAXON => 2,
	ARCHAEA_TAXON => 2157,
	EUKARYOTA_TAXON => 2759,
	VIRUSES_TAXON => 10239,
	VIROIDS_TAXON => 12884,
	UNCLASS_TAXON => 12908,
		
};

# Bacteria, Archea, Eukaryota, Viruses, Viroids, Unclassified - think of this as a constant hash
my %dol_taxa = (BACTERIA_TAXON, 0, ARCHAEA_TAXON, 0, EUKARYOTA_TAXON, 0, VIRUSES_TAXON, 0, VIROIDS_TAXON, 0, UNCLASS_TAXON, 0);

# these hashes must be populated by calling init_hashes() first
our %taxon_parent_by_node;
our %taxon_name_by_id;

my 

(

	$taxon_id_to_parent_file,
	$taxon_id_to_name_file,

);


sub init_hash_file_names
{

	my $ukb_taxonomy_file = shift;

	#DEBUGxxx make extensions constants somewhere above OR in common.pm
	# these files cache hashes produced from the file above
	$taxon_id_to_parent_file = $ukb_taxonomy_file . ".taxid2parent";
	$taxon_id_to_name_file = $ukb_taxonomy_file . ".taxid2name";
	
}


sub init_hashes
{

	my $ukb_taxonomy_file = shift;
	
	if (-e $taxon_id_to_parent_file)
		{
		%taxon_parent_by_node = %{common::load_hash_with_scalar_value($taxon_id_to_parent_file, DWCS)};
		%taxon_name_by_id = %{common::load_hash_with_scalar_value($taxon_id_to_name_file, DWCS)};
		}

	else
	
		{
		my ($ref1, $ref2) = load_ukbtdl_file($ukb_taxonomy_file);
		%taxon_parent_by_node = %{$ref1};
		%taxon_name_by_id = %{$ref2};

		common::write_hash(\%taxon_parent_by_node, $taxon_id_to_parent_file, DWCS);
		common::write_hash(\%taxon_name_by_id, $taxon_id_to_name_file, DWCS);
		}
		
}


#DEBUG convert this file initially in the future, to two simple tdl files,
#DEBUG then load those (faster!) to init the hashes
sub load_ukbtdl_file
{

	my $fn = shift;

	my %taxon_parent_by_node = ();
	my %taxon_name_by_id = ();

	#print "parsing UKB taxonomy file...\n";

	my (@cols, $taxon_id, $name, $parent_id);

	my $total = 0;

	open my $INF, "<$fn";

	while (<$INF>)

		{

		chomp;

		# skip header
		if (/^Taxon/) { next; }

		# could make this and the above string constants
		@cols = split /\t/;

		#DEBUG skip nonsense (?) lines with a single column
		#DEBUG (more than 100,000 at the end of the UKB taxonomy tdl file 
		#DEBUG last time I checked
		if (@cols < 2) { next; }
		
		($taxon_id, $name, $parent_id) = @cols[0, 2, 9];

		$taxon_name_by_id{$taxon_id} = $name;

		# note there is not always a parent column in the above list
		if (defined($parent_id))
			{
			$taxon_parent_by_node{$taxon_id} = $parent_id;
			}
		
		$total++;

		}

	close $INF;
	
	$taxon_name_by_id{+ALL_TAXON} = "all";
#DEBUG not necessary due to the nature of our subs below
=cut	
	delete $taxon_parent_by_node{+ROOT_TAXON};
	delete $taxon_parent_by_node{+VIRII_TAXON};
	delete $taxon_parent_by_node{+UNCLASS_TAXON};
=cut
	
	#print "total taxa hashed: $total\n";
	
	return (\%taxon_parent_by_node, \%taxon_name_by_id);

}


sub get_all_parent_taxa
{

	my $taxon_id = shift;

	my @parents = ();

	my $parent_taxon_id;

	while (exists $taxon_parent_by_node{$taxon_id}) 
		
		{ 
		
		$parent_taxon_id = $taxon_parent_by_node{$taxon_id}; 

		#DEBUG this bit now redundant?
=cut
		if (! defined($parent_taxon_id)) 
			{ 
			print "WARNING: $taxon_id has no known parent taxon!\n"; 
			last; 
			}
=cut

		push @parents, $parent_taxon_id;

		$taxon_id = $parent_taxon_id;

		}

	#DEBUG check for empty list?
	return \@parents;

}


sub get_common_parent_taxa
{


	my $ref = shift;
	my @taxon_ids = @{$ref};
	my (@parents, %parents);
	my @common_parents = ();
	my @dol_taxa_found = ();
	my %dol_taxa_found = ();

	foreach my $taxon_id (@taxon_ids)

		{

		@parents = @{get_all_parent_taxa($taxon_id)};
		%parents = map { $_ => 1 } @parents;

		if (! @common_parents) { @common_parents = @parents; }
		else { @common_parents = grep { exists $parents{$_} } @common_parents; }
		
		# special treatment for domains of life / superkingdoms
		@dol_taxa_found = grep { exists $dol_taxa{$_} } @parents;
		foreach (@dol_taxa_found) { $dol_taxa_found{$_} = 1; }
		}

	# if we have species from more than one domain of life, indicate this by a list starting with the
	# meta-taxon identifier, then listing all domains of life we have species in
	if (@common_parents < 2)
		{
		@dol_taxa_found = sort keys %dol_taxa_found;
		@common_parents = (ALL_TAXON, @dol_taxa_found);
		}
		
	return \@common_parents;

}

#EOF
1;
