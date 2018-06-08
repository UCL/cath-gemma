#!/bin/bash

# note that GeMMA cannot deal with superfamilies that have zero starting clusters
# so these need to be removed before running.

# should also remove superfamilies with one starting cluster as at least two
# are needed for GeMMA

# ALLOW_CACHE=true

# any commands that fail (eg mkdir, rsync) will cause the shell script to fail
set -e

# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -ne 2 ];
then
	echo
	echo "Usage: $0 <datadir> <local|legion|chuckle>"
	echo
	echo "The following files are required:"
	echo
	echo "   \${datadir}/projects.txt"
	echo "   \${datadir}/starting_clusters/\${project_id}/*.faa"
	echo
	exit
fi

function print_date {
	date=`date +'%Y/%m/%d %H:%M:%S'`
	echo "[${date}] $1"
}

# set up directory locations
GITHUB_HOME_DIR=$( readlink -f "$SCRIPT_DIR/../../../" ) # e.g. /cath/homes2/ucbtnld/github
GEMMA_DIR=$GITHUB_HOME_DIR/cath-gemma/Cath-Gemma
FF_GEN_ROOTDIR=$1            # e.g. /export/ucbtnld/gemma
# TODO: add database version to wiki
DB_VERSION=gene3d_16
RUNNING_METHOD=$2

print_date "GIT_HOME       $GITHUB_HOME_DIR"  
print_date "GEMMA_HOME     $GEMMA_DIR"
print_date "DATA_HOME      $FF_GEN_ROOTDIR"   
print_date "DB_VERSION     $DB_VERSION"          
print_date "RUN_ENV        $RUNNING_METHOD"          
print_date "PROJECT_FILE   $LOCAL_PROJECT_FILE"  

########################
# build the gemma tree # # https://github.com/UCL/cath-gemma/wiki/Running-GeMMA
########################

# parameters
LOCAL_DATA_ROOT=$FF_GEN_ROOTDIR
# specify the running method (local|legion|chuckle) as $2

# print out commands to run:
LOCAL_PROJECT_FILE="$LOCAL_DATA_ROOT/projects.txt"
if [ ! -f $LOCAL_PROJECT_FILE ]; then
	echo "! Error: projects file not found: $LOCAL_PROJECT_FILE"
	exit
fi

readarray PROJECT_IDS < $LOCAL_PROJECT_FILE
print_date "PROJECT_IDS        ${PROJECT_IDS[@]}"          

# run either locally or on legion or chuckle cluster
case "$RUNNING_METHOD" in

# locally
local)
	export PATH=/opt/local/perls/build-trunk/bin:$PATH
	echo $GEMMA_DIR/script/prepare_research_data.pl --projects-list-file $LOCAL_PROJECT_FILE --output-root-dir $LOCAL_DATA_ROOT
	;;

# on legion cluster
legion)
	# path to gemma data in legion scratch dir
	export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data
	REMOTE_DATA_ROOT=`whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma

	# make results directory
	print_date "Making results directory: $LEGION_DATA_ROOT"
	ssh legion.rc.ucl.ac.uk   mkdir -p ${LEGION_DATA_ROOT}

	# send starting cluster data
	# rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
	# rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/
	print_date "Sending project.txt file..."
	rsync -a --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/projects.txt
	for PROJECT_ID in "${PROJECT_IDS[@]}"
	do 
		print_date "Sending starting cluster data: $PROJECT_ID..."
		rsync -a --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT_ID `whoami`@login05.external.legion.ucl.ac.uk:${LEGION_DATA_ROOT}/starting_clusters/
	done

	# send the code
	print_date "Sending the code: $GEMMA_DIR -> $REMOTE_DATA_ROOT"
	# rsync --dry-run -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@login05.external.legion.ucl.ac.uk:/scratch/scratch/`whoami`/Cath-Gemma/
	rsync -a --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ $REMOTE_DATA_ROOT/

	# set data environment variables
	# ssh legion.rc.ucl.ac.uk "$( cat <<'EOT'
	# echo "Running these commands on legion..."
	print_date "Run the following commands on legion..."
	echo qrsh -verbose
	echo export LEGION_DATA_ROOT=/scratch/scratch/`whoami`/gemma_data
	echo cd /home/`whoami`/Scratch/Cath-Gemma
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
	# rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt
	# rsync --dry-run -av --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/
	print_date "Sending project.txt file..."
	rsync -a --delete ${LOCAL_DATA_ROOT}/projects.txt               `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/projects.txt

	for PROJECT_ID in "${PROJECT_IDS[@]}"
	do 
		print_date "Sending starting cluster data: $PROJECT_ID..."
		rsync -a --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT_ID `whoami`@bchuckle.cs.ucl.ac.uk:${CHUCKLE_DATA_ROOT}/starting_clusters/
	done

	# send the code
	print_date "Sending the code..."
	# rsync --dry-run -av --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/
	rsync -a --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ `whoami`@bchuckle.cs.ucl.ac.uk:/home/`whoami`/Cath-Gemma/

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
