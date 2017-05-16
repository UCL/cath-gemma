# Cath::Gemma

## Usage

Send the code over to the relevant compute cluster:

~~~
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@login05.external.legion.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
# ...or...
rsync --dry-run -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
rsync           -av --delete ~/cath-gemma/Cath-Gemma/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
~~~

Login and test:

~~~
ssh legion.rc.ucl.ac.uk
# ...or...
ssh bchuckle.cs.ucl.ac.uk

cd ~/Cath-Gemma
script/prepare_research_data.pl
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
