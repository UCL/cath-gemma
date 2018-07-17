# Cath::Gemma

## Overview

This file documents this GeMMA code. For instructions on running it, see [wiki:Running-GeMMA](https://github.com/UCL/cath-gemma/wiki/Running-GeMMA).

### Points of Note

* Within this code, `Moo::Role`s (which are akin to Java interfaces or C++ Abstract Base Classes) are used quite a bit. No other inheritance-like pattern is used.
* SGE `qsub`s must often be performed within a script executing on a compute node rather than a submit node (and you're encouraged to use a `qrsh` session to avoid running anything non-trivial on the submit node &mdash; see [wiki:Running-GeMMA](https://github.com/UCL/cath-gemma/wiki/Running-GeMMA)). To achieve this, the code uses passwordless-`ssh` to `ssh` onto the head node to execute the `qsub` command.
* One task (eg a `BuildTreeTask`) may need to execute other child tasks (eg `ProfileScanTask`s). This is implemented by requiring calls to `WorkBatch::execute_task()` to specify an Executor to use for sub-tasks. At present, the `execute_work_batch.pl` script always passes a `SpawnExecutor` for this and it allows the `SpawnExecutor` to auto-detect whether it's running in an HPC environment to determine whether to use a `SpawnHpcSgeRunner` or `SpawnLocalRunner`).
* The code doesn't currently do anything particularly smart regarding HPC failures but it does try to perform steps reasonably atomically (so they won't, eg, leave partial results files on failure).
 Batches
* Links and LinkList
  * TODOCUMENT: data structure
  * TODOCUMENT: indices
* When using the `SpawnLocalRunner`, the stdout and stderr don't appear in the correct files until the job is complete.

### Incomplete code changes

* The functionality of selecting the next (possibly speculative) bundle of merges is being abstracted into MergeBundler. There is further to go so that much of the TreeBuilder functionality can be made common but with different MergeBundler policies.

### To-do

* **TODONOW** Improve `ensure_all_alignments()` so that it doesn't execute any batches if all the alignments are already present
* **TODONOW** SpawnExecutor::execute_batch_list() Consider moving this to Executor::execute_batch_list() and have that just return if nothing to do

* Issues as documented within the [GeMMA wiki](https://github.com/UCL/cath-gemma/wiki) (particularly those pages with names beginning "Development:")
* Investigate whether we can do better than the evalue-windowing approach, (which deviates from pure trees and can still involve a lot of batches (see [wiki:Development:-Batching](https://github.com/UCL/cath-gemma/wiki/Development:-Batching)). Notes:
  * Investigate whether it's possible to get batches whilst sticking to the "pure" tree by finding reciprocal-nearest-neighbours RNNs (ie all pairs of clusters that are each other's best hit) and speculatively batch-scanning those (in the hope that many of those pairs will be merged in the pure tree)
  * Then make that batch go further by looking for what would be likely to RNN-pair with each of speculative merges (and so on as far as possible)
* Consider putting any relevant config in a file and using MooX::ConfigFromFile
* STUFF HERE TODOCUMENT :
  * Get WindowedTreeBuilder to return the number of cycles (consistently regardless of whether previously run)
  * Write code to count windows in any trace file
  * Then count all windows in all v4.0 trees
* Add a factory function for Executors and then use that to tidy up scripts
* Abstract other common code out of scripts
* Consider using `Gemma::Util::batch_into_n()` to simplify batching in WorkBatcher / WorkBatcherState
* Tidy up and sort out the code for `ssh` command-execution, `qsub` job-submitting and `qstat` job-completion-detection
* Add functionality to retry failed tasks and/or resubmit failed HPC jobs
* Add functionality to have HPC jobs just run locally if they're estimated to take a small amount of time (less than the time they're likely to spend in the queue)

## Overview of Modules

Within `lib` :

~~~no-highlight
└── Cath::Gemma                                                       The great new Cath::Gemma!
    ├── (Compute)                                                        (Organise computation into tasks, batches etc. The Tasks are typically implemented via calls to functions in Cath::Gemma::Tool.)
    │   ├── Cath::Gemma::Compute::Task                                Define a Moo::Role for representing a list of computations to perform
    │   │   ├── Cath::Gemma::Compute::Task::BuildTreeTask             Define a Cath::Gemma::Compute::Task for GeMMA tree-building computations
    │   │   ├── Cath::Gemma::Compute::Task::ProfileBuildTask          Define a Cath::Gemma::Compute::Task for sequence profile-building computations
    │   │   └── Cath::Gemma::Compute::Task::ProfileScanTask           Define a Cath::Gemma::Compute::Task for sequence profile-scanning computations
    │   ├── Cath::Gemma::Compute::TaskThreadPooler                    Execute code over an array, potentially using multiple threads
    │   ├── Cath::Gemma::Compute::WorkBatcher                         TODOCUMENT
    │   ├── Cath::Gemma::Compute::WorkBatcherState                    TODOCUMENT
    │   ├── Cath::Gemma::Compute::WorkBatchList                       TODOCUMENT
    │   └── Cath::Gemma::Compute::WorkBatch                           A batch of tasks (corresponding to a single HPC job when run under SpawnExecutor with SpawnHpcSgeRunner)
    ├── (Disk)                                                           (Represent where data should be found on disk)
    │   ├── Cath::Gemma::Disk::BaseDirAndProject                      Store a base directory for files and optionally a sub-project
    │   ├── Cath::Gemma::Disk::Executables                            Prepare align/profile-scan executables in a temporary directory that gets automatically cleaned up
    │   ├── Cath::Gemma::Disk::GemmaDirSet                            A bunch of directories, like ProfileDirSet plus a directory for scans
    │   ├── Cath::Gemma::Disk::ProfileDirSet                          A bunch of directories ( 'starting_cluster_dir', 'aln_dir' and 'prof_dir;) relating to profiles
    │   └── Cath::Gemma::Disk::TreeDirSet                             A bunch of directories, like GemmaDirSet plus a directory for trees
    ├── Cath::Gemma::Executor                                         Execute a Cath::Gemma::Compute::WorkBatchList of batches in some way
    │   ├── Cath::Gemma::Executor::ConfessExecutor                    Confess (ie die with stack-trace) on any attempt to call execute()
    │   ├── Cath::Gemma::Executor::DirectExecutor                     Execute a Cath::Gemma::Compute::WorkBatchList locally (ie directly)
    │   ├── Cath::Gemma::Executor::SpawnExecutor                      Execute a Cath::Gemma::Compute::WorkBatchList by spawning another Perl process via a shell script
    │   ├── Cath::Gemma::Executor::SpawnHpcSgeRunner                  Submit a real HPC job to run the HPC script
    │   ├── Cath::Gemma::Executor::SpawnLocalRunner                   Run a batch script by loosely simulating an HPC environment locally (useful for devel/debug)
    │   └── Cath::Gemma::Executor::SpawnRunner                        Actually run a batch script (wrapping script/execute_work_batch.pl) for SpawnExecutor in some way
    ├── (Scan)                                                           (Represent the data acquired from one or more Scans)
    │   ├── (Impl)                                                       (Store the matrix of links between clusters)
    │   │   └── Cath::Gemma::Scan::Impl::LinkList                     [For use in ScansData via LinkMatrix] Store the links between one cluster and the others
    │   │   └── Cath::Gemma::Scan::Impl::LinkMatrix                   [For use in ScansData] Store the matrix of links between clusters
    │   ├── Cath::Gemma::Scan::ScanData                               Represent the raw data from a single scan
    │   ├── Cath::Gemma::Scan::ScansDataFactory                       Functions to load ScansData from files
    │   └── Cath::Gemma::Scan::ScansData                              Store the matrix of links between clusters of starting clusters
    ├── Cath::Gemma::StartingClustersOfId                             For each cluster ID, store the IDs of the starting clusters that make it up
    ├── (Tool)                                                          (Do the steps involved in the bioinformatics jobs aligning/scanning etc) these )
    │   ├── Cath::Gemma::Tool::Aligner                                Perform an alignment of starting clusters' sequences and save the results in a file
    │   ├── Cath::Gemma::Tool::CompassProfileBuilder                  Build a COMPASS profile file
    │   └── Cath::Gemma::Tool::CompassScanner                         Scan COMPASS profiles against libraries of others and store the results in a file
    ├── (Tree)                                                          (Represent and compute a GeMMA tree (aka a MergeList because it's an ordered list of Merges))
    │   ├── Cath::Gemma::Tree::MergeBundler                           Define a Moo::Role for choosing the next list of merges to investigate/perform for a specified ScansData object
    │   │   ├── Cath::Gemma::Tree::MergeBundler::RnnMergeBundler      [to-implement] Skeleton for a MergeBundler that creates a bundle containing reciprocal-nearest-neighbours (RNNs) (and potentially also any likely RNNs involving the resulting merged nodes etc etc)
    │   │   ├── Cath::Gemma::Tree::MergeBundler::SimpleMergeBundler   [to-implement] Skeleton for a MergeBundler that creates a bundle containing the single next best merge
    │   │   └── Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler Create a bundle containing the merges within the current-best window of evalues
    │   ├── Cath::Gemma::Tree::MergeList                              An ordered list of Merges of nodes representing a tree
    │   └── Cath::Gemma::Tree::Merge                                  The data associated with a single Merge in a MergeList (ie in a tree)
    ├── Cath::Gemma::TreeBuilder                                      Define a Moo::Role for building trees; ensure that each TreeBuilder gets complete all-vs-all ScansData
    │   ├── Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder         Build a tree using only the initial all-vs-all scores by setting merged clusters scores as the highest of the mergees' scores
    │   ├── Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder          Build a tree using only the initial all-vs-all scores by setting merged clusters scores as the lowest of the mergees' scores
    │   ├── Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder            Build a tree using only the initial all-vs-all scores by setting merged clusters scores as the (geometric) mean of the mergees' scores
    │   ├── Cath::Gemma::TreeBuilder::PureTreeBuilder                 Build "pure" trees that don't use evalue windows or other short-cuts
    │   └── Cath::Gemma::TreeBuilder::WindowedTreeBuilder             Build trees using windows of evalues (eg from 1e-40 to 1e-50) as in DFX code
    ├── Cath::Gemma::Types                                            The (Moo-compatible) types used throughout the Cath::Gemma code
    └── Cath::Gemma::Util                                             Utility functions used throughout Cath::Gemma
~~~

### Overview of Scripts

Within `script`:

* `execute_work_batch.pl`               Execute a WorkBatch; can be used in various contexts including in SGE batch jobs when wrapped by `sge_submit_script.bash`
* `get_sf_seqs_from_gene3d_db.pl`       Get the input data for standard FunFam generation from a Gene3D release database
* `get_uniprot_accs_of_md5s.pl`         Extract the UniProt accessions corresponding to sequence MD5s from the CATH Biomap database
* `make-gemma-data.sh`                  Bash script to prepare GeMMA data
* `make_starting_clusters.pl`           Make the starting-cluster sequence files given the cluster definitions, the GO terms and a full sequence file
* `map_clusters.py`                     Script to apply the output of `cath-map-clusters` to a cluster membership file
* `prepare_research_data.pl`            The main script to generate a GeMMA tree for some starting clusters
* `run-gemma.sh`                        Bash script to run GeMMA
* `score_tree.pl`                       (TEMPORARY?) Score an existing tree
* `sge_submit_script.bash`              The SGE wrapper script for calling execute_work_batch.pl in SGE batches (does the SGE-specific things to keep `execute_work_batch.pl` more general)

...also related:

~~~bash
/usr/local/svn/source/update/trunk/utilities/UniprotToGo.pl Download the GO annotations associated with an input list of UniProt accessions
~~~

## Notes on Perl Usage

### Perl Version

For context:

* CentOS 5.11        : Perl v5.8.8
* CentOS release 6.9 : Perl v5.10.1
* CS compute cluster : Perl v5.20.1
* Legion UCL cluster : Perl v5.22.0 (or v5.16.3 until `module load perl`)
* Ubuntu 17.10       : Perl v5.26.0

TODOCUMENT: What version of Perl is currently supported.

The code should be kept working in reasonably old Perls. Eg, the code hasn't used non-destructive substitution regexs, introduced in Perl 5.14.

### Debugging

To turn on debug-level logging, put this at the top of the relevant script:

~~~perl
use Log::Log4perl::Tiny qw( :easy );
Log::Log4perl->easy_init({
  level  => $DEBUG,
});
~~~

Known issues:

* The code doesn't give very informative messages on Type::Tiny violations (and attempts to use `%Error::TypeTiny::CarpInternal`, `$Error::TypeTiny::StackTrace` and `$Error::TypeTiny::LastError` to help with this have failed)

## Example of running locally on a small example group

~~~bash
mkdir -p ~/gemma_play
cd ~/gemma_play
echo '3.30.70.1470' > projects.txt
mkdir -p outputs/starting_clusters
rsync -av /from/somewhere/else/3.30.70.1470/ outputs/starting_clusters/3.30.70.1470/

~/cath-gemma/Cath-Gemma/script/prepare_research_data.pl --projects-list-file $PWD/projects.txt --output-root-dir $PWD/outputs --local
~~~

## Running the Tests

Before running the tests, check all the modules compile (see commands below in Development section). Then:

~~~bash
prove -l t
~~~

## Development

To add a new module as a dependency:

~~~bash
vim Makefile.PL
cpanm -L extlib --installdeps --pureperl .
~~~

To force the install of a module:

~~~bash
cpanm -L extlib --force Params::Validate
~~~

It can be useful to graph the module dependencies, eg with [App::PrereqGrapher](https://metacpan.org/pod/App::PrereqGrapher).

To check all scripts compile:

~~~bash
find script -iname '*.pl' | sort | xargs -I VAR perl -c VAR
~~~

Run the all-modules-compile test on any Perl file changes:

~~~bash
find script lib t -iname "*.pm" -o -iname "*.pl" -o -name "*.t" | sort -u | entr -cs 'prove -l t/all_use_ok.t |& head -n 30'
~~~

To check all modules compile:

~~~bash
find lib    -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -Ilib -Iextlib/lib/perl5    -MVAR -e ''
~~~

...or from within the lib directory:

~~~bash
cd lib
find .      -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -I. -I../extlib/lib/perl5 -MVAR -e ''
~~~

To check for errors in `package` statements:

~~~bash
lsp | xargs grep -P '^package ' | tr ';' ' ' | sed 's/.pm:package//g' | sed 's/\//::/g' | sed 's/^t:://g' | sed 's/^lib:://g' | awk '$1 != $2'
~~~

## Checking Test Coverage

Ensure the Devel::Cover package is installed (which can be done in Ubuntu with package libdevel-cover-perl). Then...

~~~bash
rsync -av --exclude 'other_stuff' ~/cath-gemma/Cath-Gemma/ /tmp/Cath-Gemma/
cd /tmp/Cath-Gemma/
perl Makefile.PL
\make
cover -test +ignore ^extlib/
~~~

...and then browse to [/tmp/Cath-Gemma/cover_db/coverage.html](file:///tmp/Cath-Gemma/cover_db/coverage.html).

It can be useful to specify a single test. One way is:

~~~bash
rsync -av --exclude 'other_stuff' ~/cath-gemma/Cath-Gemma/ /tmp/Cath-Gemma/ ; rm -f /tmp/Cath-Gemma/t/*.t ; rsync -av ~/cath-gemma/Cath-Gemma/t/links.t /tmp/Cath-Gemma/t/links.t ; cd /tmp/Cath-Gemma/ ; perl Makefile.PL ; \make ; cover -test +ignore ^extlib/
~~~

...though it can probably be done more cleanly with the `cover` command line arguments.
