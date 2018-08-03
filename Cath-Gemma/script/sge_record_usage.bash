#!/bin/bash

# the intention of this script is to run in the background of a SGE job
# and record the usage to identify possible problems.

function log_info {
    echo `date` ": " $1
}

if [ ! $(command -v qstat) ]
then
    echo "Error: 'qstat' does not exist on this machine - cannot continue (are you running this within a SGE job?)"
    exit 1
fi

if [ -z ${JOB_ID+x} ]
then
    echo "Error: 'JOB_ID' env is not set - cannot continue (are you running this within a SGE job?)"
    exit 2
fi

USAGE_FILE="usage.$JOB_ID.out"
SLEEP_TIME=30

log_info `qstat -j $JOB_ID | grep 'hard resource_list'` > $USAGE_FILE

while true; do
    log_info `qstat -j $JOB_ID | grep 'usage'` >> $USAGE_FILE
    sleep $SLEEP_TIME
done
