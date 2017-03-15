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
