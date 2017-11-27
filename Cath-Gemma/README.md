# Cath::Gemma

## Example of running locally on a small example group

~~~
mkdir ~/gemma_play
cd ~/gemma_play
echo '3.30.70.1470' > projects.txt
mkdir -p outputs/starting_clusters
rsync -av /from/somewhere/else/3.30.70.1470/ outputs/starting_clusters/3.30.70.1470/

~/cath-gemma/Cath-Gemma/script/prepare_research_data.pl --projects-list-file $PWD/projects.txt --output-root-dir $PWD/outputs --local
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

To check for errors in `package` statements:

~~~
lsp | xargs grep -P '^package ' | tr ';' ' ' | sed 's/.pm:package//g' | sed 's/\//::/g' | sed 's/^t:://g' | sed 's/^lib:://g' | awk '$1 != $2'
~~~

Of possible future interest
--

 * MooX::ConfigFromFile
 * `shift if ref $_[0] eq __PACKAGE__;`


To do:

 * Add Executor factory with necessary options - abstract that out of scripts
 * Abstract common options out of scripts
 * Use batch_into_n() for batching in WorkBatcher::add_profile_build_work()