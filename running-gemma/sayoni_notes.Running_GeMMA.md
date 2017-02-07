Running GeMMA on the CS bchuckle cluster
======

~~~~~
cd /cath/people2/ucbtdas/GeMMA/
~~~~~

Copy over base directory structures required

~~~~~
rsync -av /cath/people2/ucbtnld/projects/GeMMA/dfx_base/      /cath/people2/ucbtdas/GeMMA/dfx_cath1/
rsync -av /cath/people2/ucbtnld/projects/GeMMA/dfx_base_data/ /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/
~~~~~

Rename the sub-folder PROJECT_NAME to your project name

~~~~~
mv /cath/people2/ucbtdas/GeMMA/dfx_cath1/projects/PROJECT_NAME/      /cath/people2/ucbtdas/GeMMA/dfx_cath1/projects/cath1/
mv /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/PROJECT_NAME/ /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/
~~~~~

Delete the prototype superfamily folder SUPERFAMILY_NAME and copy the required superfamily starting clusters to the data directory

~~~~~
rm -rf /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/starting_clusters/SUPERFAMILY_ID/
rsync -av /cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/starting_clusters/1.10.150.120/*.faa /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/starting_clusters/1.10.150.120/
~~~~~

Make a list of superfamilies (`superfamilies.list`) that are run and a list with superfamily sizes (`superfamilies.sizes`) :

~~~~~
echo 1.10.150.120 > /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/superfamilies.list
cp /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/superfamilies.list /cath/people2/ucbtdas/GeMMA/dfx_cath1/projects/cath1/
~~~~~

Make a tab-separated file  `/cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/superfamilies.sizes` recording that superfamily 1.10.150.120 has 437 sequences in all `.faa` files :

~~~~~
echo "1.10.150.120\t437" > /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/superfamilies.sizes
cp /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/projects/cath1/superfamilies.sizes /cath/people2/ucbtdas/GeMMA/dfx_cath1/projects/cath1/
~~~~~

Change usernames in `/cath/people2/ucbtdas/GeMMA/dfx_cath1/pipeline.config` and change the cluster directory as well

~~~~~
vim /cath/people2/ucbtdas/GeMMA/dfx_cath1/pipeline.config
~~~~~

Mirror everything to the cluster
~~~~~
rsync -av /cath/people2/ucbtdas/GeMMA/dfx_cath1/      bchuckle.cs.ucl.ac.uk:/cluster/project8/ff_stability/GeMMA_2016/cath/dfx_cath1/
rsync -av /cath/people2/ucbtdas/GeMMA/dfx_cath1_data/ bchuckle.cs.ucl.ac.uk:/cluster/project8/ff_stability/GeMMA_2016/cath/dfx_cath1_data/
~~~~~

`ssh` to the cluster and `cd` to the non-data folder in the cluster directory
~~~~~
ssh bchuckle.cs.ucl.ac.uk
cd /cluster/project8/ff_stability/GeMMA_2016/cath/dfx_cath1/
~~~~~

Run `dfx.pl` :

~~~~~
perl dfx.pl run cath1 cluster
~~~~~

Expected response:

~~~~~
Use of uninitialized value $local_user_name in concatenation (.) or string at dfx.pl line 123.
Use of uninitialized value $local_ssh_target_node in concatenation (.) or string at dfx.pl line 123.
nohup: redirecting stderr to stdout
~~~~~

Running `ps waux | grep perl` also lets you know how many instances of `dfx.pl` are running.
