#!/bin/bash

# note that GeMMA cannot deal with superfamilies that have zero starting clusters
# so these need to be removed before running.

# should also remove superfamilies with one starting cluster as at least two
# are needed for GeMMA

ALLOW_CACHE=false

if [ "$#" -ne 4 ];
then
	echo "Usage: $0 <github-home-directory> <ff-gen-rootdir> <superfamily-id> <local|legion|chuckle>"
	exit
fi

function print_date {
	date=`date +'%Y/%m/%d %H:%M:%S'`
	echo "[${date}] $1"
}

# set up directory locations
GITHUB_HOME_DIR=$1           # e.g. /cath/homes2/ucbtnld/github
GEMMA_DIR=$GITHUB_HOME_DIR/cath-gemma/Cath-Gemma
PROJECT=$3
FF_GEN_ROOTDIR=$2            # e.g. /export/ucbtnld/gemma
# TODO: add family id to wiki
FAMILY_ID=$3                 # e.g. 3.40.50.12260
FAMILY_PREFIX=${FAMILY_ID}.
# TODO: add database version to wiki
DB_VERSION=gene3d_16

############################
# remove cache if required #
############################

if [ $ALLOW_CACHE == "false" ]
then
	echo "Removing contents of $FF_GEN_ROOTDIR/alignments/$PROJECT"
	echo "Removing contents of $FF_GEN_ROOTDIR/profiles/$PROJECT"
	echo "Removing contents of $FF_GEN_ROOTDIR/scans/$PROJECT"
	rm -rf $FF_GEN_ROOTDIR/alignments/$PROJECT
	rm -rf $FF_GEN_ROOTDIR/profiles/$PROJECT
	rm -rf $FF_GEN_ROOTDIR/scans/$PROJECT
fi

########################
# build the gemma tree # # https://github.com/UCL/cath-gemma/wiki/Running-GeMMA
########################

RUNNING_METHOD=$4
print_date "Setting up to run GeMMA using the $RUNNING_METHOD method."

# parameters
LOCAL_DATA_ROOT=$FF_GEN_ROOTDIR
# specify the running method (local|legion|chuckle) as $2

# run either locally or on legion or chuckle cluster
case "$RUNNING_METHOD" in

# print out commands to run:

# locally
local)

	export PATH=/opt/local/perls/build-trunk/bin:$PATH
	echo $GEMMA_DIR/script/prepare_research_data.pl --projects-list-file $LOCAL_DATA_ROOT/projects.txt --output-root-dir $LOCAL_DATA_ROOT
	;;

# on legion cluster
legion)
	# path to gemma data in legion scratch dir
	export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data

	# make results directory
	print_date "Making results directory: $LEGION_DATA_ROOT"
	ssh legion.rc.ucl.ac.uk   mkdir -p ${LEGION_DATA_ROOT}

	# send starting cluster data
	print_date "Sending starting cluster data..."
	rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
	rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/
	rsync           -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
	rsync           -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/

	# send the code
	print_date "Sending the code..."
	rsync --dry-run -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
	rsync           -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/

	# set data environment variables
	# ssh legion.rc.ucl.ac.uk "$( cat <<'EOT'
	# echo "Running these commands on legion..."
	print_date "Run the following commands on legion..."
	if [ $ALLOW_CACHE == "false" ]
	then
		echo export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data
		echo rm $LEGION_DATA_ROOT/alignments/$PROJECT/*
		echo rm $LEGION_DATA_ROOT/profiles/$PROJECT/*
		echo rm $LEGION_DATA_ROOT/scans/$PROJECT/*
	fi
	echo qrsh -verbose
	echo export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data
	echo cd /home/ucbtnld/Scratch/Cath-Gemma
	echo module load perl
	echo script/prepare_research_data.pl --projects-list-file ${LEGION_DATA_ROOT}/projects.txt --output-root-dir ${LEGION_DATA_ROOT}
# EOT
# )"
	# ssh legion.rc.ucl.ac.uk "${SSH_COMMAND}"
	;;

# on chuckle cluster
chuckle)

	# separately from this script, need to add perl to path
	# vim ~/.bashrc
	# export PATH=/share/apps/perl/bin:$PATH

	# TODO: get dedicated gemma folder
	export CHUCKLE_DATA_ROOT=/cluster/project8/mg_assembly/gemma_data

	# make results directory
	print_date "Making results directory: $CHUCKLE_DATA_ROOT"
	ssh bchuckle.cs.ucl.ac.uk mkdir -p ${CHUCKLE_DATA_ROOT}

	# send starting cluster data
	print_date "Sending starting cluster data..."
	rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt
	rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/
	rsync           -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt
	rsync           -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/

	# send the code
	print_date "Sending the code..."
	rsync --dry-run -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
	rsync           -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/

	# set data environment variables

	# ssh bchuckle.cs.ucl.ac.uk "$( cat <<'EOT'
	print_date "Run the following commands on bchuckle..."
	echo qrsh -verbose
	echo export CHUCKLE_DATA_ROOT=/cluster/project8/mg_assembly/gemma_data
	echo cd /home/`whoami`/Cath-Gemma
	echo script/prepare_research_data.pl --projects-list-file ${CHUCKLE_DATA_ROOT}/projects.txt --output-root-dir ${CHUCKLE_DATA_ROOT}
# EOT
# )"
	;;

# nothing, because option is invalid
*)
	print_date "Invalid input. Expected local|legion|chuckle. Got:$RUNNING_METHOD."
	;;
esac
