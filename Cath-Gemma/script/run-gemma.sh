#!/bin/bash

# note that GeMMA cannot deal with superfamilies that have zero starting clusters
# so these need to be removed before running.

# should also remove superfamilies with one starting cluster as at least two
# are needed for GeMMA

ALLOW_CACHE=false

# any commands that fail (eg mkdir, rsync) will cause the shell script to fail
set -e

# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -ne 2 ];
then
	echo
	echo "Usage: $0 <datadir> <local|legion|myriad|chuckle>"
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

############################
# remove cache if required #
############################

if [ $ALLOW_CACHE == "false" ] && [ $RUNNING_METHOD == "local" ]
then
	echo "Removing contents of cache files: $FF_GEN_ROOTDIR/{alignments,profiles,scans}/$PROJECT"
	rm -rf $FF_GEN_ROOTDIR/{alignments,profiles,scans}/$PROJECT
fi

########################
# build the gemma tree # # https://github.com/UCL/cath-gemma/wiki/Running-GeMMA
########################

# parameters
LOCAL_DATA_ROOT=$FF_GEN_ROOTDIR
# specify the running method (local|legion|myriad|chuckle) as $2

# print out commands to run:
LOCAL_PROJECT_FILE="$LOCAL_DATA_ROOT/projects.txt"
if [ ! -f $LOCAL_PROJECT_FILE ]; then
	echo "! Error: projects file not found: $LOCAL_PROJECT_FILE"
	exit
fi

print_date "PROJECT_FILE   $LOCAL_PROJECT_FILE"  

readarray PROJECT_IDS < $LOCAL_PROJECT_FILE
print_date "PROJECT_IDS        ${PROJECT_IDS[@]}"          

run_hpc () {

	REMOTE_LOGIN=${REMOTE_USER}@${REMOTE_HOST}
	REMOTE_DATA_ROOT=${REMOTE_LOGIN}:${REMOTE_DATA_PATH}
	REMOTE_CODE_ROOT=${REMOTE_LOGIN}:${REMOTE_CODE_PATH}

	print_date "REMOTE_USER       $REMOTE_USER"      
	print_date "REMOTE_HOST       $REMOTE_HOST"      
	print_date "REMOTE_DATA_ROOT  $REMOTE_DATA_ROOT"          
	print_date "REMOTE_CODE_ROOT  $REMOTE_DATA_ROOT"          

	# make results directory
	print_date "Making results directory: $REMOTE_DATA_ROOT"
	ssh $REMOTE_LOGIN mkdir -p ${REMOTE_DATA_PATH} ${REMOTE_DATA_PATH}/starting_clusters

	# send starting cluster data
	print_date "Sending project.txt file..."
	set -x
	rsync -a --delete ${LOCAL_DATA_ROOT}/projects.txt ${REMOTE_DATA_ROOT}/projects.txt
	set +x
	for PROJECT_ID in "${PROJECT_IDS[@]}"
	do
		# trim white space
		PROJECT_ID="$(echo -e "${PROJECT_ID}" | tr -d '[:space:]')"
		print_date "Sending starting cluster data: $PROJECT_ID..."
		set -x
		rsync -a --delete ${LOCAL_DATA_ROOT}/starting_clusters/$PROJECT_ID/ ${REMOTE_DATA_ROOT}/starting_clusters/$PROJECT_ID/
		set +x
	done

	# send the code
	print_date "Sending the code: $GEMMA_DIR -> $REMOTE_CODE_ROOT"
	set -x
	rsync -a --delete --exclude 'submit_dir.*' --include '*' $GEMMA_DIR/ $REMOTE_CODE_ROOT/
	set +x

	# set data environment variables
	print_date "Run the following commands on ${REMOTE_HOST}..."
	echo
	echo ssh ${REMOTE_LOGIN}
	echo qrsh -verbose $QRSH_FLAGS
	echo GEMMA_DATA_ROOT=${REMOTE_DATA_PATH}
	if [ $ALLOW_CACHE == "false" ]
	then
		echo rm -rf \$GEMMA_DATA_ROOT/{alignments,profiles,scans}
	fi
	echo cd \$GEMMA_DATA_ROOT
	echo module load perl
	echo ${REMOTE_CODE_PATH}/script/prepare_research_data.pl --projects-list-file \${GEMMA_DATA_ROOT}/projects.txt --output-root-dir \${GEMMA_DATA_ROOT}
	echo
}

REMOTE_USER=${CATH_GEMMA_REMOTE_USER:-`whoami`}

# run either locally or on legion/myriad/chuckle cluster
case "$RUNNING_METHOD" in

# locally
local)
	print_date "Run the following commands ..."

	export PATH=/opt/local/perls/build-trunk/bin:$PATH
	echo $GEMMA_DIR/script/prepare_research_data.pl --projects-list-file $LOCAL_PROJECT_FILE --output-root-dir $LOCAL_DATA_ROOT
	;;

# on legion cluster
legion)
	# path to gemma data in legion scratch dir

	REMOTE_DATA_PATH=/scratch/scratch/${REMOTE_USER}/gemma_data
	REMOTE_CODE_PATH=/scratch/scratch/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=login05.external.legion.ucl.ac.uk
	QRSH_FLAGS="-l h_rt=1:0:0 -l mem=2G"
	run_hpc
	;;

# on myriad cluster
myriad)

	REMOTE_DATA_PATH=/scratch/scratch/${REMOTE_USER}/gemma_data
	REMOTE_CODE_PATH=/scratch/scratch/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=myriad.rc.ucl.ac.uk
	QRSH_FLAGS="-l h_rt=1:0:0 -l mem=2G"
	run_hpc
	;;

# on chuckle cluster
chuckle)

	REMOTE_DATA_PATH=/cluster/project8/mg_assembly/gemma_data
	REMOTE_CODE_PATH=/home/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=bchuckle.cs.ucl.ac.uk
	QRSH_FLAGS="-l h_rt=1:0:0 -l tmem=2G"
	run_hpc
	;;

*)
	print_date "Invalid input. Expected local|legion|myriad|chuckle. Got:$RUNNING_METHOD."
	;;
esac

