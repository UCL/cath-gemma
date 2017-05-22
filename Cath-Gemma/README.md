# Cath::Gemma

## Usage

Send the code over to the relevant compute cluster:

~~~
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
# ...or...
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
~~~

Login and test:

~~~
ssh legion.rc.ucl.ac.uk
cd ~/Scratch/Cath-Gemma
script/prepare_research_data.pl

# ...or...

ssh bchuckle.cs.ucl.ac.uk
cd ~/Cath-Gemma
export PATH=/share/apps/perl/bin/perl:$PATH
script/prepare_research_data.pl
~~~

~~~
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

#

Update the projects list

~~~
ls -1 temporary_example_data/tracefiles/ | sed 's/\.trace$//g' | sort -V > temporary_example_data/projects.txt
~~~
