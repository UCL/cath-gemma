# Cath::Gemma

## Overview of Code

## Overview of Modules

Within `lib` :

~~~
└── Cath::Gemma                                                       The great new Cath::Gemma!
    ├── (Compute)
    │   ├── Cath::Gemma::Compute::Task                                TODOCUMENT
    │   │   ├── Cath::Gemma::Compute::Task::BuildTreeTask             TODOCUMENT
    │   │   ├── Cath::Gemma::Compute::Task::ProfileBuildTask          TODOCUMENT
    │   │   └── Cath::Gemma::Compute::Task::ProfileScanTask           TODOCUMENT
    │   ├── Cath::Gemma::Compute::TaskThreadPooler                    Execute code over an array, potentially using multiple threads
    │   ├── Cath::Gemma::Compute::WorkBatcher                         TODOCUMENT
    │   ├── Cath::Gemma::Compute::WorkBatcherState                    TODOCUMENT
    │   ├── Cath::Gemma::Compute::WorkBatchList                       TODOCUMENT
    │   └── Cath::Gemma::Compute::WorkBatch                           TODOCUMENT
    ├── (Disk)
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
    ├── (Scan)
    │   ├── (Impl)
    │   │   └── Cath::Gemma::Scan::Impl::LinkList                     [For use in ScansData] Store the links from one cluster to another
    │   │   └── Cath::Gemma::Scan::Impl::Links                        TODOCUMENT
    │   ├── Cath::Gemma::Scan::ScanData                               TODOCUMENT
    │   ├── Cath::Gemma::Scan::ScansDataFactory                       TODOCUMENT
    │   └── Cath::Gemma::Scan::ScansData                              TODOCUMENT
    ├── Cath::Gemma::StartingClustersOfId                             TODOCUMENT
    ├── (Tool)
    │   ├── Cath::Gemma::Tool::Aligner                                Perform an alignment of starting clusters' sequences and save the results in a file
    │   ├── Cath::Gemma::Tool::CompassProfileBuilder                  Build a COMPASS profile file
    │   └── Cath::Gemma::Tool::CompassScanner                         Scan COMPASS profiles against libraries of others and store the results in a file
    ├── (Tree)
    │   ├── Cath::Gemma::Tree::MergeBundler                           TODOCUMENT
    │   │   ├── Cath::Gemma::Tree::MergeBundler::RnnMergeBundler      TODOCUMENT
    │   │   ├── Cath::Gemma::Tree::MergeBundler::SimpleMergeBundler   TODOCUMENT
    │   │   └── Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler TODOCUMENT
    │   ├── Cath::Gemma::Tree::MergeList                              An ordered list of Merges of nodes representing a tree
    │   └── Cath::Gemma::Tree::Merge                                  The data associated with a single Merge in a MergeList (ie in a tree)
    ├── Cath::Gemma::TreeBuilder                                      TODOCUMENT
    │   ├── Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder         TODOCUMENT
    │   ├── Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder          TODOCUMENT
    │   ├── Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder      TODOCUMENT
    │   ├── Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder            TODOCUMENT
    │   ├── Cath::Gemma::TreeBuilder::PureTreeBuilder                 TODOCUMENT
    │   └── Cath::Gemma::TreeBuilder::WindowedTreeBuilder             TODOCUMENT
    ├── Cath::Gemma::Types                                            The (Moo-compatible) types used throughout the Cath::Gemma code
    └── Cath::Gemma::Util                                             TODOCUMENT
~~~

### Overview of Scripts

Within `script`:

~~~
 * execute_work_batch.pl         Execute a WorkBatch; can be used in various contexts including in SGE batch jobs when wrapped by `sge_submit_script.bash`
 * get_sf_seqs_from_gene3d_db.pl Get the input data for standard FunFam generation from a Gene3D release database
 * get_uniprot_accs_of_md5s.pl   Extract the UniProt accessions corresponding to sequence MD5s from the CATH Biomap database
 * make_starting_clusters.pl     Make the starting-cluster sequence files given the cluster definitions, the GO terms and a full sequence file
 * prepare_research_data.pl      The main script to generate a GeMMA tree for some starting clusters
 * score_tree.pl                 (TEMPORARY?) Score an existing tree
 * sge_submit_script.bash        The SGE wrapper script for calling execute_work_batch.pl in SGE batches (does the SGE-specific things to keep `execute_work_batch.pl` more general)
~~~

...also related:

~~~
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

~~~
use Log::Log4perl::Tiny qw( :easy );
Log::Log4perl->easy_init({
	level  => $DEBUG,
});
~~~

Known issues:

 * The code doesn't give very informative messages on Type::Tiny violations (and attempts to use `%Error::TypeTiny::CarpInternal`, `$Error::TypeTiny::StackTrace` and `$Error::TypeTiny::LastError` to help with this have failed)

## Example of running locally on a small example group

~~~
mkdir -p ~/gemma_play
cd ~/gemma_play
echo '3.30.70.1470' > projects.txt
mkdir -p outputs/starting_clusters
rsync -av /from/somewhere/else/3.30.70.1470/ outputs/starting_clusters/3.30.70.1470/

~/cath-gemma/Cath-Gemma/script/prepare_research_data.pl --projects-list-file $PWD/projects.txt --output-root-dir $PWD/outputs --local
~~~

## Running the Tests

Before running the tests, check all the modules compile (see commands below in Development section). Then:

~~~
prove -l t
~~~

## Development

To add a new module as a dependency:

~~~
vim Makefile.PL
cpanm -L extlib --installdeps .
~~~

To force the install of a module:
~~~
cpanm -L extlib --force Params::Validate
~~~

It can be useful to graph the module dependencies, eg with https://metacpan.org/pod/App::PrereqGrapher .

To check all scripts compile:

~~~
find script -iname '*.pl' | sort | xargs -I VAR perl -c VAR
~~~

Run the all-modules-compile test on any Perl file changes:

~~~
find script lib t -iname "*.pm" -o -iname "*.pl" -o -name "*.t" | sort -u | entr -cs 'prove -l t/all_use_ok.t |& head -n 30'
~~~

To check all modules compile:

~~~
find lib    -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -Ilib -Iextlib/lib/perl5    -MVAR -e ''
~~~

...or from within the lib directory:

~~~
cd lib
find .      -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -I. -I../extlib/lib/perl5 -MVAR -e ''
~~~

To check for errors in `package` statements:

~~~
lsp | xargs grep -P '^package ' | tr ';' ' ' | sed 's/.pm:package//g' | sed 's/\//::/g' | sed 's/^t:://g' | sed 's/^lib:://g' | awk '$1 != $2'
~~~

## Checking Test Coverage

Ensure the Devel::Cover package is installed (which can be done in Ubuntu with package libdevel-cover-perl). Then...

~~~
rsync -av --exclude 'other_stuff' ~/cath-gemma/Cath-Gemma/ /tmp/Cath-Gemma/
cd /tmp/Cath-Gemma/
perl Makefile.PL
\make
cover -test +ignore ^extlib/
~~~

...and then browse to [/tmp/Cath-Gemma/cover_db/coverage.html](file:///tmp/Cath-Gemma/cover_db/coverage.html).

It can be useful to specify a single test. One way is:

~~~
rsync -av --exclude 'other_stuff' ~/cath-gemma/Cath-Gemma/ /tmp/Cath-Gemma/ ; rm -f /tmp/Cath-Gemma/t/*.t ; rsync -av ~/cath-gemma/Cath-Gemma/t/links.t /tmp/Cath-Gemma/t/links.t ; cd /tmp/Cath-Gemma/ ; perl Makefile.PL ; \make ; cover -test +ignore ^extlib/
~~~

...though it can probably be done more cleanly with the `cover` command line arguments.

## Issues to be aware of

When using the SpawnLocalRunner, the stdout and stderr don't appear in the correct files until the job is complete.

## Future

 * Document
 * Test
 * Track test coverage with [Devel::Cover](https://metacpan.org/pod/Devel::Cover) [related blog post](http://blogs.perl.org/users/neilb/2014/08/check-your-test-coverage-with-develcover.html) and put summary of process here

### To Do 1

 * Add Executor factory with necessary options - abstract that out of scripts
 * Abstract common options out of scripts
 * Use batch_into_n() for batching in WorkBatcher::add_profile_build_work()

### To Do from A3 pad

 * SSH wrapper
 * `qstat`-ing
 * Job tracking etc
 * Document and then fix Executor OO violation

### To Do Soon from A3 pad

 * Get WindowedTreeBuilder to return the number of cycles (consistently regardless of whether previously run)
 * Write code to count windows in any trace file
 * Then count all windows in all v4.0 trees
 * Make child-submitting executor smarter (eg use if estimated time > x)

### To Do Now from A3 pad

 * Change back splice for Optional[CathGemmaCompassProfileType] and just use maybe instead
 * Sort out qstat-ing (time and loading)
 * Add a 'retry' (ie persevere with retries) option to execute()
 * Add an executor that does nothing but assert that there's nothing to do (which can be used in tests)
 * Add an executor that resubmits smaller jobs
 * Add MergeBundler
   * Methods:
     * what to execute
     * what to merge
   * SimpleMergeBundler
   * RnnMergeBundler
   * RnnAndsomeMergeBundler
   * WindowedMergeBundler
 * Integrate into a TreeBuilder

### Of possible future interest

 * MooX::ConfigFromFile
 * `shift if ref $_[0] eq __PACKAGE__;`
