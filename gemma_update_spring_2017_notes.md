GeMMA Update Work, Spring 2017<br>Notes from Tony
==

Task
--

The work is to write new code to perform the GeMMA step of the FunFam protocol. The new code should be more maintainable and should use better practices so that it causes fewer problems on the CS cluster.

### GeMMA's Context

The FunFam protocol processes the Gene3D sequences for a given superfamily as follows:
 1. &nbsp; &dArr; &nbsp; Group into S90 clusters using CD-HIT
 1. &nbsp; &dArr; &nbsp; Remove S90 clusters that don't have acceptable GO evidence
 1. &nbsp; &dArr; &nbsp; **Run GeMMA on remaining S90 clusters to generate tree**
 1. &nbsp; &dArr; &nbsp; Run FunFHMMer to select the cut-points of tree
 1. &nbsp; &dArr; &nbsp; Create FunFams from the groups below those cut points

So this work is within step 3 <sub><sup>*(though benchmarking will also involve steps 4-5 and the work may possibly also touch on issues in steps 1 (see [Overlap](#quality-overlap)) and 5 (see [Renumbering](#usability-renumbering)))*</sup></sub>.

### What GeMMA Does

**Goal** : &nbsp; GeMMA aims to find the tightest possible tree between the nodes using a greedy, agglomerative clustering approach.

**Input** : &nbsp; A bunch of non-overlapping "starting clusters" of sequences (with 90% sequence similarity). Each starting cluster has an identifying integer, `N` and an associated file `N.faa` containing the sequences in the cluster.

**Output** : &nbsp; A `.trace` file specifying an ordered list of pairwise cluster-merge operations that, applied in that order, merge the starting clusters into one root node. Each line of the file is of the format:
<br>
&emsp; `1st_mergee_num 2nd_mergee_num new_merged_clust_num evalue`
<br>
The new clusters are numbered consecutively, starting from the highest starting cluster number plus one. FunFHMMer uses both the structure of this tree and its evalues.
<br>
In discussing the work, we've decided that GeMMA should also start outputting alignment files for each of the nodes in the final `.trace` file because otherwise FunFHMMer just has to regenerate all these alignments again. Sayoni has confirmed that FunFHMMer won't care about the order in which the starting clusters / sequences appear in this alignment.

**Scores** : &nbsp; The evalue between two clusters comes from a COMPASS comparison between alignments of the sequences in each of those clusters. When two clusters are merged, a combined alignment is generated for the new cluster and is COMPASS-scored against the other clusters' alignments.

High-level Work Aims
--

### Code quality

 * Write higher quality code that's:
   * More maintainable,
   * Better-documented,
   * Better tested (ie with an easily re-runnable test-suite),
   * Able to time its own major steps and report the results and
   * Less disposed to indulge in bad practices, particularly re the CS cluster.

### Assessment

 * Establish and document a reusable benchmark for assessing GeMMA
 * Record the new performance on the benchmark for future comparisons
 * Ensure it doesn't represent a regression from the previous version(s)

### Speed / Quality of Results

Tristan's work suggests that better practices on the CS cluster may well improve the computational throughput on the CS cluster.

Beyond that:
 * possibly try improving GeMMA's speed without substantially sacrificing quality,
 * possibly try improving GeMMA's quality with substantially sacrificing speed and
 * possibly investigate whether we get better results with an overlap criterion when generating the starting clusters.

### Usability

 * Avoid new code being so dependent on a specific, intricate directory structure
 * Restore the ability to process (smaller) superfamilies in standalone (ie single-machine, non-HPC) mode
 * Allow configuration of:
   * how much computation to put into one compute job
   * (possibly: how long tasks should be expected to take before being put into a new cluster job, rather than just being run then-and-there)

### Practical Deployability

 * Ideally work with Natalie and Sayoni to ensure they're happy the code is usable.
 * Possibly try to get Natalie and Sayoni started on running GeMMA across v4.1.0?

Available GeMMA Results for Comparison
--

Whilst the GeMMA code is being written, it'll be very useful to compare its results against results from the current GeMMA. There are two sources of results from the current GeMMA:

1. **Dave's Dir** A complete set of data across all superfamilies for v4.0 in Dave's directories.
1. **Existing Code** The current code produces similar but slightly different results to those in **Dave's Dir**. This may well be due to changed versions of MAFFT/COMPASS. <sub><sup>*(And a brief investigation suggested that trying to chase this up would be more effort than it'd be worth.)*</sup></sub>

Since the only comprehensive data we already have is on v4.0, it makes sense to restrict all comparisons and benchmarks to v4.0 to keep things simpler and to make results comparable.

### Regression Testing

Given we'll already need to be benchmarking for this project (see [Benchmarking](#benchmarking), immediately below), this is a good opportunity to run the **Existing Code** on some small subset of superfamilies and establish there isn't any regression from the **Dave's Dir** results.

Benchmarking
--

It will be very valuable to build a meaningful, clear, well-documented, reusable benchmark. This will allow us to ensure that the current version hasn't regressed from previous results, that the new version doesn't regress from the current version and that any future changes can be assessed.

We've talked about three levels of benchmark:

 * Tree Benchmark - a very fast way to assess whether one tree is substantially worse/better than another on the same starting clusters
 * EC Codes Benchmark - an intermediate measure of the number of EC codes associated with each FunFam
 * Function Benchmark - more biologically meaningful benchmarks to indicate value for function prediction.

Ideas for each type of benchmark...

### Tree Benchmark

We think that a good metric for comparing different trees generated from the same starting clusters is the average evalue: the lower the average evalue, the tighter the tree. This has the advantage of being extremely easy to calculate and of being intuitively meaningful. However it won't allow comparison between trees for different sets of starting clusters.

<sub><sup>*(The calculation should use the [geometric mean](https://en.wikipedia.org/wiki/Geometric_mean), rather than the [arithmetic mean](https://en.wikipedia.org/wiki/Arithmetic_mean), which would be excessively dominated by the worse evalues. To see this, consider the evalues: 1e-3, 1e-16, 1e-20. The (arithmetic) mean is ~3.33e-4 &mdash; almost completely dominated by the largest value. The geometric mean is 1e-13.)*</sup></sub>

### EC Codes Benchmark

Assess the number of EC codes associated with each FunFam.

### Function Benchmark

We will also need a broader benchmark that allows us to assess the effect of changes on our ability to accurately predict function.

There is a clear trade-off here: making the benchmark bigger allows us to be more confident about the accuracy/precision of the results; but keeping the benchmark smaller makes it easier to run and that will likely have a big impact on the usefulness of the benchmark.

We've decided to not use CAFA in the bencharking.

Agreed key benchmarking superfamilies:

1. HUPs,    [3.40.50.620](http://www.cathdb.info/version/latest/superfamily/3.40.50.620)
1. TPPs,    [3.40.50.970](http://www.cathdb.info/version/latest/superfamily/3.40.50.970)
1. Enolase, [3.20.20.120](http://www.cathdb.info/version/latest/superfamily/3.20.20.120) and [3.30.390.10](http://www.cathdb.info/version/latest/superfamily/3.30.390.10)

Key Task Priorities
--

I propose my priorities should be:

 1. Submit jobs for the existing code on agreed benchmark superfamilies to the CS cluster
 1. Build tools to generate key data on the farm
 1. Submit jobs for new code on the CS cluster, prioritising benchmark superfamilies
 1. Continue to assemble the results from these jobs whilst tackling the following steps...
 1. Build a well-designed, well-tested, well-commented, well-documented script that reproduces small/medium trees in standalone (ie single-machine, non-HPC) mode
 1. Extend this to:
     * handle the large amount of data involved in large superfamilies
     * run effectively on the CS cluster
 1. (Guided by timing breakdowns from real runs), iteratively:
    1. Benchmark
    1. Explore possible improvements (see [Possible Improvements](#possible-improvements), immediately below)

Possible Improvements
--

 * [[Speed+simplicity] Always need to realign and build profile?](#speedsimplicity-always-need-to-realign-and-build-profile)
 * [[Speed+quality] Batch handling](#speedquality-batch-handling)
 * [[Speed] Faster aligning?](#speed-faster-aligning)
 * [[Speed] Faster](#speed-faster)
 * [[Quality] Overlap](#quality-overlap)
 * [[Usability] Renumbering](#usability-renumbering)

### [Speed+simplicity] Always need to realign and build profile?

In principle, the existing algorithm is similar to running, say, TCluster on an all-versus-all COMPASS matrix. The key difference that substantially complicates things is that each merged cluster is (re-aligned and then) re-scored against the other clusters. This means that the clustering procedure and the re-scoring procedure need to be interleaved, which substantially complicates everything.

It may be possible to simplify by using a multi-linkage (complete-linkage), average-linkage or single-linkage clustering strategy to at least reduce the degree of interleaving.

This would result in fewer, larger batches of jobs to compute, which will typically work better on the farm.

This needn't necessarily preclude the final tree having the "correct" final evalues, which could be all calculated and inserted into the final tree at the end.

This will only be possible if it turns out that the best/average/worst score from a pair of merged clusters is a reasonably good predictor of equivalent score from the merged cluster, at least within certain circumstances. This can be tested relatively quickly.

### [Speed+quality] Batch handling

The current GeMMA algorithm attempts to ameliorate the interleaving issues described above by working within intervals of evalues in powers of 1e-10, eg (1e-50 to 1e-40), then (1e-40 to 1e-30), etc... The algorithm commits to a full list of merges within an interval before aligning and rescoring the newly formed clusters. This allows a decent batch of merges to be computed together rather than incurring huge waits associated with submitting single jobs consecutively

This can cause the results to diverge a bit from the "pure greedy" tree. For example, given a set-up like this:

~~~
.
    A  ←– 1.2e-20 –┐
    ↑              |
    |              ↓
 1.1e-20           C  ←–––––––– 9.9e-11 ––––––––→  D
    |              ↑
    ↓              |
    B  ←– 1.3e-20 –┘
~~~

After `A` and `B` are merged, we'd want `C` to be merged with `A+B` before `D` <sub><sup>*(assuming the evalue between `C` and `A+B` is comparable to 1.3e-20)*</sup></sub>, like this:

~~~
`     ┌– A
    ┌–┤
    | └– B
  ┌–┤
  | └––– C
 –┤
  └––––– D
~~~

...but the existing approach would immediately merge it with `D`, which would eventually result in this:

~~~
`    ┌– A
  ┌––┤
  |  └– B
 –┤
  |  ┌– C
  └––┤
     └– D
~~~

An alternative strategy may be able to achieve similar or larger batch sizes whilst avoiding these deviations from the "pure greedy" tree: instead of using intervals, it would identify *all* pair-merges that, *at that time*, can be seen will be included in the final "pure greedy" tree. The criterion is: pairs for which each of the pair's sub-clusters is the other's best-scoring match.

This approach would avoid the within-the-current-interval merges that cause the deviations from the final "pure greedy" tree, whilst still generating decent-sized batches by taking merges from the full evalue range, not just within a particular interval.

This approach could go further by identifying more merges that are *very likely* to be part of the "pure greedy" tree and adding them to the batch to be re-aligned and re-scored but not committing to them until the scores confirm it. These would be cases, like `C` (above), in which two clusters being merged share a best-scoring match, and that match's best-scoring match is one of those two original clusters.

### [Speed] Faster aligning?

It looks as though the majority of the computation on the many, smaller families would be spent on aligning sequences. Though this consumes a small amount of time per family, it may add up to a quite a lot of computation. Can this be measured? If substantial, can it be reduced?

Possible strategies (for more info, see file [Alignment Speed Notes](alignment_speed_notes.md)) :
 * Remove identical sequences from starting clusters when aligning (quick test suggests this doesn't affect evalues; does it improve speed?)
 * Don't re-align within clusters when merging them (by telling which groups of input sequences are already aligned). This could be parametrised, eg: "only re-align `n` levels deeper than the new cluster's root"; "only re-align until the evalues are `x` times better than the evalue for the new merge".
 * Upgrade MAFFT (initial tests suggest: ~22% faster on smallish cluster; ~32% slower on largish cluster)
 * Use different aligner, eg Clustal Omega (initial tests suggest: 976% faster on smallish cluster; 514% slower on largish cluster)

### [Speed] Faster

I've already spent some time investigating ways to perform COMPASS comparisons quickly. The architecture must also enable the machine to focus on those comparisons to achieve maximum throughput. Beyond this, substantial further reductions in time spent on COMPASS comparisons can only come from doing fewer comparisons.

Of course, this issue's particularly important for large families where the existing GeMMA code deploys random sampling to reduce computation. It may be possible to find ways to improve the coverage of the best evalues for a given budget of COMPASS comparisons. I like the COMPASSing with initial S30 clusters approach described within [GeMMA paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2817468/). One possible way to build on that:
 * use those COMPASS results to sub-cluster at a reasonably strict evalue
 * do an all-versus-all COMPASS of the sub-cluster reps to find any cross-cluster links
 * do all-versus-all comparisons between the members of any sub-cluster pairs that for a cross S30 cluster link

### [Quality] Overlap

We've seen instances of a starting S90 cluster (Dave's directories, v4.1, 2.20.100.10, 12528.faa) with a wide diversity of lengths from 16 residues up to 47 residues (~2.9x). It seems questionable whether this diversity is a good starting point.

Depending on time, it may be possible to investigate whether changing this improves results. This would require taking some agreed superfamilies through the entire protocol (see [GeMMA's context](#gemmas-context)). (Natalie on step 2: "[...] I don't think it should be a hassle. There will be some work needed, but I don't think it will be a huge amount.")

<sub><sup>*(Before doing this, it'd be worth checking that (a) this issue is in the current protocol and (b) if we were to change it, we wouldn't just find that the COMPASS scores would immediately re-merge the overlap-separated clusters.)*</sup></sub>

It looks like we can apply a cut-off using the following option that Sayoni and Ian identified from the [CD-HIT User's Guide](http://weizhongli-lab.org/lab-wiki/doku.php?id=cd-hit-user-guide) :

    -s  length difference cut-off, default 0.0
        if set to 0.9, the shorter sequences need to be
        at least 90% length of the representative of the cluster

<sub><sup>*Note: It may be worth choosing quite a strict cut-off because it looks like this clustering criterion is based on a single rep, which may mean it's looser than our multi-linkage clustering. For example, it might be something like: if the rep is 60 residues long, then with `-s 0.6` the sequences can have a range from 36 residues to 100 residues (because 0.6 \* 100 = 60 and 0.6 \* 60 = 36).* </sup></sub>

### [Usability] Renumbering

Previously, the FunFam numbers have been practically arbitrary numbers (eg 12528) that emerge from the process, which is arguably a bit strange for users. But it may well be better than the alternative of sequentially renumbering the arbitrarily ordered FunFams from one upwards at the end of the process, because that might mislead users into thinking that FunFam numbers persist over consecutive CATH releases.

But FunFams represent functionally coherent groups of sequences, so we should hope that many of them *will* have fairly stable equivalents across consecutive releases.

We could get the best of both worlds if we had a program to renumber based on the numbers of the previous release so that FunFams that are most preserved across releases *do* keep their numbers and the others get new numbers. For each superfamily, the program would take a list of the FunFam members for the previous release and the new release and would spit out a renumbering of the new FunFams. This could be pretty simple and pretty fast. Under the covers, it could do something like a much-simplified version of the Genome3D SCOP/CATH mapping where it inherits a previous FunFam's number to a new FunFam if the new FunFam contains domains that match, say, at least 70% of 70% of the old FunFam's domains.

<sub><sup>*In principle, this could compare to multiple previous releases so that if some FunFam groupings revert to how they were in a previous release, the previously used numbers would be re-activated. But I think this is excessive.*</sup></sub>

Relevant References
--

 * [*GeMMA: functional subfamily classification within superfamilies of predicted protein structural domains*, 2010, David A Lee, Robert Rentzsch, Christine Orengo. NAR](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2817468/)
 * [Robert Rentzsch's PhD Thesis, 2011](http://discovery.ucl.ac.uk/1348549/1/1348549.pdf)
 * [CATH Wiki GeMMA Entry](http://www.cathdb.info/wiki/doku/?id=projects:gemma)

---

Some Issues to Address at 10th March 2017 Meeting
--

 * Handover to whom?
 * What function benchmark?
 * Are we motivated to investigate the starting-clusters overlap issue? If so, what overlap cut-off and which superfamilies/benchmark?
