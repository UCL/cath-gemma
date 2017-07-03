# Cath::Gemma

## Usage

~~~
setenv LOCAL_DATA_ROOT   /cath/people2/ucbctnl/GeMMA/v4_0_0
setenv LEGION_DATA_ROOT  /scratch/scratch/`whoami`/gemma_data
setenv CHUCKLE_DATA_ROOT /cluster/project6/cathrelease/work/2017_05_10.gemma_recode
~~~

...or for bash...

~~~
export LOCAL_DATA_ROOT=/cath/people2/ucbctnl/GeMMA/v4_0_0
export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data
export CHUCKLE_DATA_ROOT=/cluster/project6/cathrelease/work/2017_05_10.gemma_recode
~~~

(please update these values in the docs as appropriate)

### Send to compute cluster

Send the starting clusters data:

~~~
rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt       `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/ `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/
rsync           -av --delete ${LOCAL_DATA_ROOT}/projects.txt       `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
rsync           -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/ `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/
# ...or...
rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt       `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt
rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/ `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/
rsync           -av --delete ${LOCAL_DATA_ROOT}/projects.txt       `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt
rsync           -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/ `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/
~~~

Send the code:

~~~
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
# ...or...
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
~~~

### Run

Login and test:

~~~
ssh legion.rc.ucl.ac.uk
qrsh -verbose -l h_rt=1:0:0,h_vmem=2G
# <set data environment variables, as above>
cd ~/Scratch/Cath-Gemma
module load perl
script/prepare_research_data.pl --starting-cluster-root-dir ${LEGION_DATA_ROOT}/starting_clusters  --projects-list-file ${LEGION_DATA_ROOT}/projects.txt --output-root-dir ${LEGION_DATA_ROOT}

# ...or...

ssh bchuckle.cs.ucl.ac.uk
qrsh -verbose -l h_rt=1:0:0,h_vmem=2G,tmem=2G
# <set data environment variables, as above>
cd ~/Cath-Gemma
export PATH=/share/apps/perl/bin:$PATH
script/prepare_research_data.pl --starting-cluster-root-dir ${CHUCKLE_DATA_ROOT}/starting_clusters --projects-list-file ${CHUCKLE_DATA_ROOT}/projects.txt --output-root-dir ${CHUCKLE_DATA_ROOT}
~~~

~~~
rsync -av `whoami`@login05.external.legion.ucl.ac.uk:/home/ucbctnl/Scratch/Cath-Gemma/fred/                          ~/cath-gemma/legion_fred/
rsync -av `whoami`@login05.external.legion.ucl.ac.uk:/home/ucbctnl/Scratch/Cath-Gemma/temporary_example_data/output/ ~/cath-gemma/legion_output/
rsync -av `whoami`@bchuckle.cs.ucl.ac.uk:/home/ucbctnl/Cath-Gemma/fred/                                              ~/cath-gemma/bchuckle_fred/
rsync -av `whoami`@bchuckle.cs.ucl.ac.uk:/home/ucbctnl/Cath-Gemma/temporary_example_data/output/                     ~/cath-gemma/bchuckle_output/
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

Consider graphing module dependencies, eg with https://metacpan.org/pod/App::PrereqGrapher

#

Update the projects list

~~~
ls -1 temporary_example_data/tracefiles/ | sed 's/\.trace$//g' | sort -V > temporary_example_data/projects.txt
~~~

To check all scripts compile:

~~~
find script -iname '*.pl' | sort | xargs -I VAR perl -c VAR
~~~

To check all modules compile:

~~~
find lib    -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -Ilib -Iextlib/lib/perl5    -MVAR -e ''
~~~

or

~~~
cd lib
find .      -iname '*.pm' | sort | sed 's/^lib\///g' | sed 's/\.pm$//g' | sed 's/\.\///g' | sed 's/\//::/g' | xargs -I VAR perl -Ilib -I../extlib/lib/perl5 -MVAR -e ''
~~~


Of possible future interest
--

 * MooX::ConfigFromFile
 * `shift if ref $_[0] eq __PACKAGE__;`


To do:

 * Add Executor factory with necessary options - abstract that out of scripts
 * Abstract common options out of scripts
 * Copy batch_into_n() from /cath/homes2/ucbctnl/cath-gemma/tree_inspection/get_ec_codes_by_starting_cluster.pl into Util.pm
 * Use batch_into_n() for batching in WorkBatcher::add_profile_build_work()