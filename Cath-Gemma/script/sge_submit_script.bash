#!/bin/bash -l

this_cmnd=`readlink -f ${BASH_SOURCE[0]}`
for word in "$@"; do
	this_cmnd="$this_cmnd \"$word\"";
done
echo "To repeat this run, use:"
echo "/bin/bash -c 'SGE_TASK_ID=$SGE_TASK_ID $this_cmnd'"
echo

if [ "$#" -lt 3 ]; then
	echo "GeMMA submit bash script expects at least three arguments (the execute perl script; the job batch file; the cluster environment name) but got $#";
	exit;
fi

# Where a compute-cluster provides a more recent perl through the module system, this will pick it up
( ( module avail perl ) 2>&1 | grep -q perl ) && module load perl

echo "SGE_BINARY_PATH      : $SGE_BINARY_PATH"
echo "SGE_CELL             : $SGE_CELL"
echo "SGE_JOB_SPOOL_DIR    : $SGE_JOB_SPOOL_DIR"
echo "SGE_O_HOME           : $SGE_O_HOME"
echo "SGE_O_HOST           : $SGE_O_HOST"
echo "SGE_O_LOGNAME        : $SGE_O_LOGNAME"
echo "SGE_O_PATH           : $SGE_O_PATH"
echo "SGE_O_SHELL          : $SGE_O_SHELL"
echo "SGE_O_WORKDIR        : $SGE_O_WORKDIR"
echo "SGE_ROOT             : $SGE_ROOT"
echo "SGE_STDERR_PATH      : $SGE_STDERR_PATH"
echo "SGE_STDOUT_PATH      : $SGE_STDOUT_PATH"
echo "SGE_TASK_ID          : $SGE_TASK_ID"

EXECUTE_BATCH_SCRIPT=$1
BATCH_FILES_FILE=$2
GEMMA_CLUSTER_NAME=$3

echo
echo "HOSTNAME             : $HOSTNAME"
echo
echo "EXECUTE_BATCH_SCRIPT : $EXECUTE_BATCH_SCRIPT"
echo "BATCH_FILES_FILE     : $BATCH_FILES_FILE"
echo "GEMMA_CLUSTER_NAME   : $GEMMA_CLUSTER_NAME"
echo
echo "REMAINING ARGS       : ${@:4}"

BATCH_FILE=$(awk "NR==$SGE_TASK_ID" $BATCH_FILES_FILE)
echo "BATCH_FILE           : $BATCH_FILE"

export GEMMA_CLUSTER_NAME

$EXECUTE_BATCH_SCRIPT $BATCH_FILE "${@:4}"
