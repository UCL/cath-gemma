Tony Self Notes<br>GeMMA Update, Spring 2017
==

General
--

 * Are there simple tools for visualising the trees?
 * Attempt to make steps succeed/fail atomically (ie generate file to temp filename and rename on success)
 * Make some attempt to avoid potential problems with concurrent attempts to do the same thing.
 * Include mechanism to start HPC work on biggest superfamilies first so that the longest running S/F is started ASAP (and so that the small jobs will neatly fill in idle slots towards the end)

Generating data
--

 * As soon as benchmark superfamilies are agreed, submit the existing code on those superfamilies to the CS cluster.
 * Create code tools for submitting/checking/gathering/locally-performing lists of GeMMA computation tasks, independently of their provenance. Perhaps support freezing/thawing these lists.
 * Generate all alignments/profiles twice for both starting-cluster-orderings (depth-first-tree-ordering because that matches previous results; numeric-ordering because that allows equivalent groups' data to be reused, no matter the provenance)
 * Make all non-starting clusters' filenames be identified only by a hash of the starting clusters (with the ordering preserved), without reference to the name of the new node in the current set-up.
 * Immediately generate alignments/profiles for all nodes in all trees in Dave's directories and then calculate all the evalues for all those trees' pairwise merges. Then use these to make fixed up versions of the same trees.
 * For now, keep alignment files, because we may want to re-use alignments when merging clusters so as to not have to re-align the entire cluster from scratch.

Steps
--

 * How to write the partial progress? Will need list of merge-ops that have been committed and possibly a separate list of merge-ops that have been (or are being) computed. Or does that latter list add nothing over the checking for the presence of files that'll have to be done anyway?

Code architecture
--

 * Trawl `have_a_play_around.pl` for the sorts of data that will be required and design it in from the start.

Renumbering tool
--

### Overview

 * Avoid mentioning FunFams in the code and try to keep the tool FunFam-ignorant so it could theoretically be used for other clusterings, like S35-clustering, so long as the domains' segment locations are specified in the required format
 * (But don't worry about multi-chain domains for now)

### Options

 * One positional argument: `--working-clustmemb-file <file>` a filename of a file containing the working cluster membership
 * Options:
   * `--map-from-clustmemb-file <file>     Map numbers from previous clusters specified in <file> to their equivalents in the working clusters where possible\n(of, if unspecified, renumber all working clusters from 1 upwards)\nCluster names in this file must be positive integers`
   * `--min-equiv-dom-ol <percent> (=66)   Define domain equivalence as: sharing more than <percent>% of residues (over the longest domain)\n(where <percent> must be %ge; 50)`
   * `--min-equiv-clust-ol <percent> (=66) Define cluster equivalence as: more than <percent>% of the map-from cluster's members having equivalents in the working cluster\n(where <percent> must be %ge; 50)`
   * `--batch-id <id>                      Append batch ID <id> to the results output (equivalent to the first column in a --multi-batch-file file)` (append as last column of each results line)
   * `--output-file <file>                 Write output to file <file> (or, if unspecified, to stdout)`
   * `--summary                            Print a summary of the renumbering`
   * (Don't implement for now, just comment in code: `--renumber-new-start-num   For --map-from-member-file, renumber unmapped clusters starting from <num> (rather than from one above the highest number in the <file>)`)
 * Enforce that both overlap values must be &ge; 50. Then can just deal in simple equivalences: each domain can have at most one equivalent; A is equivalent to B iff B is equivalent to A

Usage strings:

~~~~~.no-highlight
The cluster membership file should contain lines like:

cluster_name domain_id

...where domain_id must be and domains cannot belong to more than one cluster in a batch.
~~~~~

**TODO** : Finish this...

### Files
 * Membership file format is lines like: `cluster_name domain_id`
 * For `cluster_name`, enforce positive-integers in `--map-from-clustmemb-file` file. Allow any string in general.
 * Enforce that input cannot specify same domain as belonging to multiple clusters
 * `domain_id` is like: `42b6526f23c300bd94ca74ede87b3fa5/675-706_799-819`.
 * `domain_id` parsing procedure:
   1. split at the last `/`
   1. treat everything before as the sequence (or possibly PDB chain) on which the domain sits
   1. treat everything after as segment information
   1. split the segments on `_` (and possibly `,`?)
   1. assume each segment is a pair of sequential numbers, separated by a '-'
 * Output format: `mapping_cluster_name renumbered_num (batch_id)`

### Code Organisation

 * Move useful stuff from `resolve` into new directory (`seq_core`?) / namespace (`cath::seq`?) and reuse in this code:
   * `res_arrow` (and maybe rename? `seq_arrow`?)
   * `hit_seg` (and maybe rename? `seq_seg`)
   * possibly abstract out start/stop/fragments trick from `calc_hit` into some new `seq_core` class (`seq_seg_list`?)
 * Put code in new directory (`cluster`?) and namespace (`clust`?) and create a module test `mod-test-cluster`

### Code

 * Vaguely aim to make cluster classes reusable in any future clustering code
 * Create class `seq_domain_cluster_list` to list the domains on a single chain and their clusters - important to encapsulate at this location because it this may be the location of substantial optimisation opportunities
 * (**TODO**) Should `seq_domain_cluster_list` store the domain's clusters as strings or ints (ie have the clients do the `external_name` <-> `internal_offset` mapping)?
 * (**TODO**) Start with `seq_domain_cluster_list` being something like `vector<tuple<dom_id_str, seq_seg_list, cluster_id>>` (**TODO**)
 * (**TODO**) cluster list class?

### Ordering

**new cluster ordering criteria** :
 * descending on sum over domains of `sqrt(total_dom_length)` (ie earlier FunFams have more/longer sequences, with more emphasis on having more sequence)
 * descending on number of sequences
 * ascending on average mid-point index
 * ascending on first domain ID

### Algorithm

 * Read new membership into:
   * an `unordered_map<string, seq_domain_cluster_list>` where the string key is the sequence ID (up to the point in the domain IDs where the segment locations starts)
   * A cluster list (**TODO**, see above)
 * Prepare an empty mapping from the list of new clusters to their old cluster equivalents (implement as `size_opt_vec`; each position corresponds to a new cluster; initialise to correct size with values of none; on identifying an equivalence, set the position corresponding to the new cluster to the external number ID of the equivalent old cluster; throw on attempt to set equivalence for a new cluster that already has one)
 * If doing mapping:
 * Read the old membership into a cluster list (**TODO**, see above)
 * For each old cluster:
   * Work out the target number of domain equivalences that a new cluster must attain to be deemed the equivalent cluster
   * Prepare an empty map from new cluster to domain equivalences achieved so far
   * For each old cluster member:
     * Search in the `unordered_map` to find a domain equiv
     * If a domain equivalent is found:
       * Find equivalent domain's cluster
       * Increment that cluster's counter of domain equivalents
       * If the counter has reached the target, add the cluster mapping to the list and move to the next cluster
 * Get the list of new clusters that don't have an old equiv, sort by **new cluster ordering criteria** (above)
 * Add numbers for those new clusters, starting from one plus the highest number in the old clusters (or zero)
 * Print out mapping

### Multi batch processing

 * Provide `--multi-batch-file` option for handling multiple batches (eg superfamilies) with an input file that contains a pair of filenames per line:
 * Format of each line is: `batch_id working_clust_memb_file prev_clust_memb_file` where the final `prev_clust_memb_file` is optional (and if it's absent, the algorithm performs from-one renumbering)
 * Should it be permitted for batch file to mix presence/absence of `prev_clust_memb_file`?
 * How to handle output?
   * Output to separate files (in directory of new cluster membership file but can be overridden with option; find last dot before mismatch point of basenames and replace remaining with new output suffix)?
   * Or output together? In which case, the batch input file should have an ID per line too (or could use the tactic above to extract common part of file basenames?). Probably go for this. After all, output files will have one line per cluster, not per domain, so should be much smaller.

### Summary/Statistics

 * Make `--summary` activate a visitor (but not in the double-dispatch sense of the [visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern))
 * Error on attempt to specify `--summary` when not performing mappings
 * For all old domains mapped, store highest overlap-over-longest in a big list.
 * For all old clusters, store the highest percentage that was mapped to any one new cluster (or 0).
 * For now, just implement each of these as a `doub_vec`.

~~~~~.no-highlight

Domain Mapping
==

This section describes how well the map-from domains could be mapped to new domains (and vice versa). The quality of a mapping between a pair of domains is defined as the percentage overlap over the longer domain (ie the percentage of the longer domain's residues shared with the other domain). In this run, the cut-off for defining domain-equivalence was **X**%.


Domains from Map-From Clusters
--

| Category                                                         | Number | Percentage |
|------------------------------------------------------------------|--------|------------|
| All                                                              |    123 |     100.0% |
| &nbsp; ...of which:                                              |        |            |
| &nbsp; &bull; Equivalence-mapped    (ie **X** < overlap        ) |    100 |      81.3% |
| &nbsp; &bull; Insufficiently-mapped (ie 0     < overlap ≤ **X**) |     20 |      16.3% |
| &nbsp; &bull; Completely-unmapped   (ie         overlap = 0)     |      3 |       2.4% |

Domains from New Clusters
--

| Category                                                        | Number | Percentage |
|-----------------------------------------------------------------|--------|------------|
| All                                                             |    142 |     100.0% |
| &nbsp; ...of which:                                             |        |            |
| &nbsp; &bull; Equivalence-mapped     (ie overlap > **X**      ) |    100 |      70.4% |
| &nbsp; &bull; Not equivalence-mapped (ie overlap ≤ **X**      ) |     42 |      29.6% |


Distribution of Domain Mapping Percentages for Domains from Map-From Clusters
--

Excluding completely-unmapped domains:

| Percentile through distribution of mapping percentages | Mapping Percentage |
|--------------------------------------------------------|--------------------|
|                                                     25 |                30% |
|                                                     50 |                40% |
|                                                     75 |                50% |
|                                                     90 |                60% |
|                                                     95 |                70% |
|                                                     98 |                80% |
|                                                     99 |                90% |
|                                                    100 |                90% |

Including completely unmapped domains:

| Percentile through distribution of mapping percentages | Mapping Percentage |
|--------------------------------------------------------|--------------------|
|                                                     25 |                30% |
|                                                     50 |                40% |
|                                                     75 |                50% |
|                                                     90 |                60% |
|                                                     95 |                70% |
|                                                     98 |                80% |
|                                                     99 |                90% |
|                                                    100 |                90% |


Cluster Mapping
==

This section describes how well the old clusters could be mapped to the new clusters (and vice versa). The quality of a mapping between a pair of clusters is defined as the percentage of the domains in the map-from cluster that have an equivalent domain in the new cluster. In this run, the cutoff for defining cluster-equivalence was **Y**%.

Map-From Clusters
--

| Category                             | Number | Percentage |
|--------------------------------------|--------|------------|
| All                                  |      6 |     100.0% |
| &nbsp; ...of which:                  |        |            |
| &nbsp; &bull; Equivalence-mapped     |      4 |      66.7% |
| &nbsp; &bull; Not equivalence-mapped |      2 |      33.3% |

New Clusters
--

| Category                             | Number | Percentage |
|--------------------------------------|--------|------------|
| All                                  |      7 |     100.0% |
| &nbsp; ...of which:                  |        |            |
| &nbsp; &bull; Equivalence-mapped     |      4 |      57.1% |
| &nbsp; &bull; Not equivalence-mapped |      3 |      42.9% |

Distribution of Cluster-mapping Percentages for Map-From Clusters
--

Excluding completely-unmapped clusters:

**this needs tweaking**

| Percentile through distribution of mapping percentages | Mapping Percentage |
|--------------------------------------------------------|--------------------|
|                                                     25 |                30% |
|                                                     50 |                40% |
|                                                     75 |                50% |
|                                                     90 |                60% |
|                                                     95 |                70% |
|                                                     98 |                80% |
|                                                     99 |                90% |
|                                                    100 |                90% |

Including completely unmapped clusters:

| Percentile through distribution of mapping percentages | Mapping Percentage |
|--------------------------------------------------------|--------------------|
|                                                     25 |                30% |
|                                                     50 |                40% |
|                                                     75 |                50% |
|                                                     90 |                60% |
|                                                     95 |                70% |
|                                                     98 |                80% |
|                                                     99 |                90% |
|                                                    100 |                90% |

~~~~~
