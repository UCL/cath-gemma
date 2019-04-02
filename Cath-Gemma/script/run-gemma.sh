#!/bin/bash

# note that GeMMA cannot deal with superfamilies that have zero starting clusters
# so these need to be removed before running.

# should also remove superfamilies with one starting cluster as at least two
# are needed for GeMMA

ALLOW_CACHE="${ALLOW_CACHE:-1}"

# any commands that fail (eg mkdir, rsync) will cause the shell script to fail
set -e

# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

# The default project folder name is 'gemma_data'. The user can define the project folder name by providing the third argument.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -lt 2 ];
then
	echo
	echo "Usage: $0 <datadir> <local|legion|myriad|chuckle|grace> [<project_folder_name>]"
	echo
	echo "The following files are required:"
	echo
	echo "   \${datadir}/projects.txt"
	echo "   \${datadir}/starting_clusters/\${project_id}/*.faa"
	echo
	echo "The <project_folder_name> is optional (default: 'gemma_data')"
	echo
	echo "Set ALLOW_CACHE=0 to delete any existing alignments, profiles, scans (!)"
	echo "Set GEMMA_REMOTE_USER to set the remote user if different from your local user"
	echo "Set GEMMA_CLUSTER_MAX_HOURS to override the maximum time ceiling"
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
PROJECT_NAME=$3
PROJECT_NAME=${PROJECT_NAME:-gemma_data}

############################
# remove cache if required #
############################

if [ $RUNNING_METHOD == "local" ]; then
	if [ "$ALLOW_CACHE" = "0" ]; then
		print_date "Removing contents of cache files: $FF_GEN_ROOTDIR/{alignments,profiles,scans}/$PROJECT"
		rm -rf $FF_GEN_ROOTDIR/{alignments,profiles,scans}/$PROJECT
	else
		print_date "Cache is allowed (ALLOW_CACHE=1) so not removing contents of cache files"
	fi
fi


print_date "--------------------------------------"
print_date "ALLOW_CACHE    $ALLOW_CACHE"
print_date "GIT_HOME       $GITHUB_HOME_DIR"  
print_date "GEMMA_HOME     $GEMMA_DIR"
print_date "DATA_HOME      $FF_GEN_ROOTDIR"   
print_date "DB_VERSION     $DB_VERSION"          
print_date "RUN_ENV        $RUNNING_METHOD"
print_date "PROJECT_NAME   $PROJECT_NAME"
print_date "--------------------------------------"

########################
# build the gemma tree # # https://github.com/UCL/cath-gemma/wiki/Running-GeMMA
########################

# parameters
LOCAL_DATA_ROOT=$FF_GEN_ROOTDIR
# specify the running method (local|legion|myriad|chuckle|grace) as $2

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
	print_date "REMOTE_CODE_ROOT  $REMOTE_CODE_ROOT"          

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
	print_date "Done"

	# set data environment variables
	echo
	echo "Copy/paste the following commands to submit this GeMMA project on ${REMOTE_HOST}..."
	echo
	echo ssh ${REMOTE_LOGIN}
	echo qrsh -verbose -l $SGE_REQUEST_FLAGS
	echo 
	echo export GEMMA_CLUSTER_NAME=${RUNNING_METHOD}
	echo export GEMMA_CLUSTER_MEM=15G
	echo '# export GEMMA_CLUSTER_MAX_HOURS=200'
	echo GEMMA_DATA_ROOT=${REMOTE_DATA_PATH}
	echo '# rm -rf $GEMMA_DATA_ROOT/{alignments,profiles,scans}'
	echo 'mkdir -p $GEMMA_DATA_ROOT'
	echo 'cd $GEMMA_DATA_ROOT'
	echo '( ( module avail perl ) 2>&1 | grep -q perl ) && module load perl'
	echo ${REMOTE_CODE_PATH}/script/prepare_research_data.pl --projects-list-file \${GEMMA_DATA_ROOT}/projects.txt --output-root-dir \${GEMMA_DATA_ROOT}
	echo
	echo "NOTES:" 
	echo "- uncomment the 'rm' function in the commands above to delete any existing data files"
	echo "- change the value of GEMMA_CLUSTER_MEM if you require more memory (eg '31G', '63G', '127G')"
	echo "- use GEMMA_CLUSTER_MAX_HOURS to change the default max time (eg myriad=72, cs=100)"
	echo "- do not run more than one gemma project in the same data directory"
	echo
}


REMOTE_USER=${GEMMA_REMOTE_USER:-`whoami`}

# run either locally or on legion/myriad/chuckle/grace cluster
case "$RUNNING_METHOD" in

# locally
local)
	print_date "Run the following commands ..."

	export PATH=/opt/local/perls/build-trunk/bin:$PATH
	echo $GEMMA_DIR/script/prepare_research_data.pl --local --projects-list-file $LOCAL_PROJECT_FILE --output-root-dir $LOCAL_DATA_ROOT
	;;

# on legion cluster
legion)
	# path to gemma data in legion scratch dir

	REMOTE_DATA_PATH=/scratch/scratch/${REMOTE_USER}/${PROJECT_NAME}
	REMOTE_CODE_PATH=/scratch/scratch/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=login05.external.legion.ucl.ac.uk
	SGE_REQUEST_FLAGS="h_rt=2:0:0,h_vmem=7G"
	run_hpc
	;;

# on myriad cluster
myriad)

	REMOTE_DATA_PATH=/scratch/scratch/${REMOTE_USER}/${PROJECT_NAME}
	REMOTE_CODE_PATH=/scratch/scratch/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=myriad.rc.ucl.ac.uk
	SGE_REQUEST_FLAGS="h_rt=2:0:0,mem=7G"
	run_hpc
	;;

# on grace cluster
grace)

	REMOTE_DATA_PATH=/scratch/scratch/${REMOTE_USER}/${PROJECT_NAME}
	REMOTE_CODE_PATH=/scratch/scratch/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=grace.rc.ucl.ac.uk
	SGE_REQUEST_FLAGS="h_rt=2:0:0,mem=7G"
	run_hpc
	;;

# on chuckle cluster
chuckle)

	REMOTE_DATA_PATH=/home/${REMOTE_USER}/${PROJECT_NAME}
	REMOTE_CODE_PATH=/home/${REMOTE_USER}/Cath-Gemma
	REMOTE_HOST=bchuckle.cs.ucl.ac.uk
	SGE_REQUEST_FLAGS="h_rt=4:0:0,h_vmem=7G,tmem=7G"
	run_hpc
	;;

*)
	print_date "Invalid input. Expected local|legion|myriad|chuckle|grace. Got:$RUNNING_METHOD."
	;;
esac

