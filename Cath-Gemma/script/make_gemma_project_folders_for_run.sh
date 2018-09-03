#!/bin/bash

# This script takes a list of superfamilies (Superfamily ID in the first column) and creates a project dir ready for running GeMMA

# Note:

# The default directory for starting_clusters is set to /cath/people2/ucbtnld/projects/cath-gemma/starting_clusters.
# The user can change this by providing the third argument.

SFLIST=$1
TARGETDIR=$2
SCDIR=$3

SCDIR=${SCDIR:-/cath/people2/ucbtnld/projects/cath-gemma/starting_clusters}

if [ "$#" -lt 2 ] ;
then
	echo
	echo "Usage: $0 <SFLIST> <target_folder_name> <OPTIONAL: starting_cluster_dir (default: /cath/people2/ucbtnld/projects/cath-gemma/starting_clusters)"
	echo 
	exit
fi

echo
echo "SFLIST       $SFLIST"
echo "TARGETDIR    $TARGETDIR"
echo "SCDIR        $SCDIR"
echo

mkdir -p ${TARGETDIR}
mkdir -p ${TARGETDIR}/starting_clusters

PROJECTFILE=${TARGETDIR}/projects.txt

# remove any project file already present
if [[ -f ${PROJECTFILE} ]]; then
    rm ${PROJECTFILE}
fi

cat $SFLIST | while read line
do
    
	tmparray=($line)
	superfamily=${tmparray[0]}
	
    echo "copying $superfamily"
    echo "$superfamily" >> ${PROJECTFILE}
    
    rsync -a --delete ${SCDIR}/${superfamily}/ ${TARGETDIR}/starting_clusters/${superfamily}/
    
done
