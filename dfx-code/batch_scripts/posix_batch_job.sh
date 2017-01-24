#!/bin/sh

# WARNING: do not change this unless you know exactly why!

# this script takes (or ignores) parameters in the following fashion:

# 1 = $wrapper_script (full path)
# 2 = $project 
# 3 = $superfamily
# 4 = $overwrite_mode
# 5 = $run_id
# 6 = $batch_work_dir (full path)

# where $optional_script_parameters is a comma-separated list of values 
# without spaces before or after commas OR an empty string
# 7 = $optional_script_parameters

# NOTE: the output/ and errors/ subdirs of $batch_work_dir must exist too!

$1 $2 $3 $4 $5 $7 > $6/$3.output 2>$6/$3.errors

mv -f $6/$3.output $6/output
mv -f $6/$3.errors $6/errors

hostname=`hostname`

touch $6/$hostname"_$5_$3.finished"

