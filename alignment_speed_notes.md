Alignment Speed Notes
=====================

The problem
-----------

Initial testing on 1.10.150.120 (with 45 starting clusters) suggests that for these smaller S/Fs, the MAFFT alignment takes the majority of the time. Though this isn't the worst bottleneck, the total alignment time will nevertheless accumulate over the long tail of smallish superfamilies.

Note: the initial MAFFT alignments appear to be fast (about 6/second) but the later larger ones are slower (though the existing GeMMMA code switches to using rougher, faster aligning at 200 sequences).

Possible strategy 1: Remove identical sequences
-------------------

The starting clusters often contain quite a few identical sequences. We want to know whether removing such redundancy would:
 * preserve the profile evalues
 * speed up the alignments

An initial test of the first issue seemed to suggest that it *would* preserve evalues:

~~~~~
cp /cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/starting_clusters/1.10.150.120/{869,920}.faa .
cp 869.faa 869_mod.faa
cp 920.faa 920_mod.faa
mv 869.faa 869_org.faa
mv 920.faa 920_org.faa
st *_mod.faa
# ...and then remove S100 redundants
setenv MAFFT_BINARIES /dev/shm/mafft_binaries_dir
/dev/shm/mafft --amino --anysymbol --localpair --maxiterate 1000 --quiet 869_mod.faa > 869_mod.aligned.faa
/dev/shm/mafft --amino --anysymbol --localpair --maxiterate 1000 --quiet 920_mod.faa > 920_mod.aligned.faa
/dev/shm/mafft --amino --anysymbol --localpair --maxiterate 1000 --quiet 869_org.faa > 869_org.aligned.faa
/dev/shm/mafft --amino --anysymbol --localpair --maxiterate 1000 --quiet 920_org.faa > 920_org.aligned.faa

echo '>A;A;' | tr ';' '\n' > small.faa

/dev/shm/compass_wp_310      -g 0.50001 -i small.faa -j 869_mod.aligned.faa -p1 small.prof -p2 869_mod.compass_wp_310.prof
/dev/shm/compass_wp_310      -g 0.50001 -i small.faa -j 920_mod.aligned.faa -p1 small.prof -p2 920_mod.compass_wp_310.prof
/dev/shm/compass_wp_310      -g 0.50001 -i small.faa -j 869_org.aligned.faa -p1 small.prof -p2 869_org.compass_wp_310.prof
/dev/shm/compass_wp_310      -g 0.50001 -i small.faa -j 920_org.aligned.faa -p1 small.prof -p2 920_org.compass_wp_310.prof
/dev/shm/compass_db1Xdb2_310 -g 0.50001 -i 869_org.compass_wp_310.prof -j 920_org.compass_wp_310.prof -n 0 | grep evalue -i
/dev/shm/compass_db1Xdb2_310 -g 0.50001 -i 869_mod.compass_wp_310.prof -j 920_mod.compass_wp_310.prof -n 0 | grep evalue -i
~~~~~

Possible strategy 2: Re-use alignments from sub clusters
--------------------

At present, each newly-merged cluster is completely realigned, even though its sub-clusters have already been aligned.

MAFFT let's you tell it which groups of input sequences are already aligned. It's likely that that will allow MAFFT to do much less work, if each step doesn't involve re-aligning the entire batch of sequences but just pairwise-aligning two, already-well-aligned alignments. After all, the process of merging clusters of sequences by merging the most similar first, is exactly the process that should be well matched to that approach.

Possible strategy 3: upgrade MAFFT
--------------------

We're currently using MAFFT 6.864, which appears to be from around 2011/2012.

The latest version is MAFFT 7.309, from 26th January 2017.

The two versions were tested on:
 * An alignment of 175 sequences with high-quality settings - the upgrade improved the time from ~3.00s to ~2.35s.
 * An alignment of 437 sequences with low-quality  settings - the upgrade worsened the time from ~0.22s to ~0.29s.

Possible strategy 3: replace MAFFT with Clustal Omega
--------------------

Clustal Omega was compared with MAFFT 6.864 on:
 * An alignment of 175 sequences with high-quality settings - the switch to Clustal Omega improved the time from ~3.00s to ~0.41s.
 * An alignment of 437 sequences with low-quality  settings - the switch to Clustal Omega worsened the time from ~0.22s to 1.14s.
