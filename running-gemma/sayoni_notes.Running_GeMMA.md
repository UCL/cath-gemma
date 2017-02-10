Running GeMMA on the CS bchuckle cluster
======

If using `tcsh` or `csh`, set environment variables to suitable values like this:

~~~~~
setenv ROOT_SMB_DIR             /cath/people2/ucbtdas/GeMMA
setenv PROJECT_NAME             dfx_cath1
setenv ROOT_CS_CLUSTER_DIR      /cluster/project8/ff_stability/GeMMA_2016/cath
setenv STARTING_CLUSTERS_SOURCE /cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/starting_clusters
~~~~~

...or if using `bash`, set environment variables to suitable values like this:

~~~~~
export ROOT_SMB_DIR=/cath/people2/ucbtdas/GeMMA
export PROJECT_NAME=dfx_cath1
export ROOT_CS_CLUSTER_DIR=/cluster/project8/ff_stability/GeMMA_2016/cath
export STARTING_CLUSTERS_SOURCE=/cath/people2/ucbcdal/dfx_funfam2013_data/projects/gene3d_12/starting_clusters
~~~~~

Start in the root SMB directory:

~~~~~
cd $ROOT_SMB_DIR
~~~~~

Copy over base directory structures required

(*TO DO: Change this to get the data from the cath-gemma GitHub repo*)

~~~~~
rsync -av /cath/people2/ucbtnld/projects/GeMMA/dfx_base/      $ROOT_SMB_DIR/$PROJECT_NAME/
rsync -av /cath/people2/ucbtnld/projects/GeMMA/dfx_base_data/ $ROOT_SMB_DIR/${PROJECT_NAME}_data/
~~~~~

Rename the sub-folder `PROJECT_NAME` to your project name `$PROJECT_NAME` :

~~~~~
mv $ROOT_SMB_DIR/$PROJECT_NAME/projects/PROJECT_NAME        $ROOT_SMB_DIR/$PROJECT_NAME/projects/$PROJECT_NAME
mv $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/PROJECT_NAME $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME
~~~~~

Delete the prototype superfamily folder `SUPERFAMILY_NAME` and copy the required superfamily starting clusters to the data directory

~~~~~
rm -rf $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/starting_clusters/SUPERFAMILY_ID/
rsync -av $STARTING_CLUSTERS_SOURCE/1.10.150.120/*.faa $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/starting_clusters/1.10.150.120/
~~~~~

Make a list of superfamilies (`superfamilies.list`) that are run and a list with superfamily sizes (`superfamilies.sizes`) :

~~~~~
echo 1.10.150.120 > $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/superfamilies.list
\cp  $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/superfamilies.list $ROOT_SMB_DIR/$PROJECT_NAME/projects/$PROJECT_NAME/
~~~~~

Make a tab-separated file  `$ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/superfamilies.sizes` recording that superfamily 1.10.150.120 has 437 sequences in all `.faa` files :

~~~~~
echo "1.10.150.120\t437" > $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/superfamilies.sizes
\cp  $ROOT_SMB_DIR/${PROJECT_NAME}_data/projects/$PROJECT_NAME/superfamilies.sizes $ROOT_SMB_DIR/$PROJECT_NAME/projects/$PROJECT_NAME/
~~~~~

Change usernames in `$ROOT_SMB_DIR/$PROJECT_NAME/pipeline.config` and change the cluster directory as well

~~~~~
vim $ROOT_SMB_DIR/$PROJECT_NAME/pipeline.config
~~~~~

Mirror everything to the cluster
~~~~~
rsync --dry-run -av --delete $ROOT_SMB_DIR/$PROJECT_NAME/        bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/$PROJECT_NAME/
rsync           -av --delete $ROOT_SMB_DIR/$PROJECT_NAME/        bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/$PROJECT_NAME/
rsync --dry-run -av --delete $ROOT_SMB_DIR/${PROJECT_NAME}_data/ bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/${PROJECT_NAME}_data/
rsync           -av --delete $ROOT_SMB_DIR/${PROJECT_NAME}_data/ bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/${PROJECT_NAME}_data/
~~~~~

`ssh` to the CS cluster:

~~~~~
ssh bchuckle.cs.ucl.ac.uk
~~~~~

Then **re-set the environment variable parameters**, as at the top of this file.

`cd` to the project directory:

~~~~~
cd $ROOT_CS_CLUSTER_DIR/$PROJECT_NAME/
~~~~~

Run `dfx.pl` :

~~~~~
perl dfx.pl run $PROJECT_NAME cluster
~~~~~

Expected response:

~~~~~
Use of uninitialized value $local_user_name in concatenation (.) or string at dfx.pl line 123.
Use of uninitialized value $local_ssh_target_node in concatenation (.) or string at dfx.pl line 123.
nohup: redirecting stderr to stdout
~~~~~

Running `ps waux | grep perl` also lets you know how many instances of `dfx.pl` are running.

Afterwards, back on the SMB machines, rsync the results back:

~~~~~
rsync --dry-run -av --delete  bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/$PROJECT_NAME/        $ROOT_SMB_DIR/$PROJECT_NAME/
rsync           -av --delete  bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/$PROJECT_NAME/        $ROOT_SMB_DIR/$PROJECT_NAME/
rsync --dry-run -av --delete  bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/${PROJECT_NAME}_data/ $ROOT_SMB_DIR/${PROJECT_NAME}_data/
rsync           -av --delete  bchuckle.cs.ucl.ac.uk:$ROOT_CS_CLUSTER_DIR/${PROJECT_NAME}_data/ $ROOT_SMB_DIR/${PROJECT_NAME}_data/
~~~~~
