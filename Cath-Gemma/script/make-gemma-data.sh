#!/bin/bash

# warning - if changed to false then all files will be deleted
ALLOW_CACHE=true

if [ "$#" -ne 3 ];
then
	echo "Usage: $0 <github-home-directory> <ff-gen-rootdir> <superfamily-id>"
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
CDHIT=/cath/people2/ucbtnld/software/cd-hit-v4.6.7-2017-0501/cd-hit

#####################################
# create data for starting clusters # # https://github.com/UCL/cath-gemma/wiki/Running-the-Full-FunFam-Protocol
#####################################

print_date "Changing to work directory: $FF_GEN_ROOTDIR..."
cd $FF_GEN_ROOTDIR

# clear files if cache is false
if [ $ALLOW_CACHE = false ]
then
	print_date "No cache allowed so clearing all files for ${FAMILY_ID}"
	rm ${FAMILY_PREFIX}${DB_VERSION}.*
	rm -rf alignments/${FAMILY_ID}
	rm -rf profiles/${FAMILY_ID}
	rm -rf scans/${FAMILY_ID}
	rm -rf starting_clusters/${FAMILY_ID}
	rm -rf trees/${FAMILY_ID}
fi

# get superfamily sequences from gene3d database
# TODO: add usage for this script
SEQFILE="${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids__seqs"
if [ $ALLOW_CACHE = true ] && [ -e $SEQFILE ]
then
	print_date "Using cached file: $SEQFILE"
else
	print_date "Getting superfamily sequences for superfamily $FAMILY_ID..."
	$GEMMA_DIR/script/get_sf_seqs_from_gene3d_db.pl --cath $FAMILY_ID
fi

# grab the (sorted, unique) UniProt accessions
print_date "Creating UniProt accessions file..."
UNIPROT_ACC_FILE="${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs"
awk '{print $1}' < $SEQFILE | sort -u > $UNIPROT_ACC_FILE

# retrieve the GO annotations
# note that 404 not found errors could be due to now-obsolete UniProt accessions
UNIPROT_GO_FILE="${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.out"
UNIPROT_GO_FILE_ERR=${UNIPROT_GO_FILE/%out/err}
if [ $ALLOW_CACHE = true ] && [ -e $UNIPROT_GO_FILE ]
then
	print_date "Using cached file: $UNIPROT_GO_FILE"
else
	print_date "Getting UniProt to GO term info..."
	( nohup /usr/local/svn/source/update/trunk/utilities/UniprotToGo.pl -t 20 --force $UNIPROT_ACC_FILE > $UNIPROT_GO_FILE ) >& $UNIPROT_GO_FILE_ERR
fi

# grab a list of uniprot accessions that weren't recognised
grep -iv 'Internal Server Error' ${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.err | grep -Pio "API response failed for uniprot accession '\S+'" | tr "'" " " | awk '{print $7}' > ${FAMILY_PREFIX}${DB_VERSION}.unrecognised_uniprot_accs
# cat ${FAMILY_PREFIX}${DB_VERSION}.unrecognised_uniprot_accs

# build required files
# build FASTA file, excluding the sequences with unrecognised UniProt accessions
grep -Fvwf ${FAMILY_PREFIX}${DB_VERSION}.unrecognised_uniprot_accs ${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids__seqs | sort -k2,2 | uniq -f 1 | awk '{print ">" $2 "\n" $3 }' > ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa

# join GO annotations by UniProt accession with original file to get GO annotations by id
sort -k 1b,1 ${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.out > ${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.out.join_sorted
awk '{print $1, $2}' < ${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids__seqs | sort -k 1b,1 > ${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids.join_sorted
join ${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids.join_sorted ${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.out.join_sorted | cut -d ' ' -f 2- > ${FAMILY_PREFIX}${DB_VERSION}.ids_go_terms.out
rm -f ${FAMILY_PREFIX}${DB_VERSION}.uniprot_acc_go_terms.out.join_sorted ${FAMILY_PREFIX}${DB_VERSION}.uniprot_accs__ids.join_sorted

# form s90 clusters
print_date "Forming the S90 clusters..."
$CDHIT -i ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa -o ${FAMILY_PREFIX}${DB_VERSION}.nr90.out -c 0.9 -s 0.95 -n 5 -d 9999

# make project directory
print_date "Making the project directory at: $PWD/starting_clusters/$PROJECT..."
mkdir -p starting_clusters/$PROJECT

# make starting clusters
print_date "Making starting clusters..."
print_date "Trying: perl -I $GEMMA_DIR/extlib/lib/perl5 $GEMMA_DIR/script/make_starting_clusters.pl --cluster-infile ${FAMILY_PREFIX}${DB_VERSION}.nr90.out.clstr --ids-go-terms-infile ${FAMILY_PREFIX}${DB_VERSION}.ids_go_terms.out --sequences-infile ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa -o starting_clusters/$PROJECT"
perl -I $GEMMA_DIR/extlib/lib/perl5 $GEMMA_DIR/script/make_starting_clusters.pl --cluster-infile ${FAMILY_PREFIX}${DB_VERSION}.nr90.out.clstr --ids-go-terms-infile ${FAMILY_PREFIX}${DB_VERSION}.ids_go_terms.out --sequences-infile ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa -o starting_clusters/$PROJECT

# if no starting clusters created, run again to allow some of the GO IEA terms
if [ -z "$(ls -A starting_clusters/$PROJECT)" ]
then
	print_date "No starting clusters produced so far. Will now retry by including some GO IEA terms relating to UniProt keywords"
	# echo "Trying: perl -I $GEMMA_DIR/extlib/lib/perl5 $GEMMA_DIR/script/make_starting_clusters.pl --cluster-infile ${FAMILY_PREFIX}${DB_VERSION}.nr90.out.clstr --ids-go-terms-infile ${FAMILY_PREFIX}${DB_VERSION}.ids_go_terms.out --sequences-infile ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa -o starting_clusters/$PROJECT --included-go-iea-terms IEA:UniProtKB-KW,IEA:UniProtKB-EC"
	perl -I $GEMMA_DIR/extlib/lib/perl5 $GEMMA_DIR/script/make_starting_clusters.pl --cluster-infile ${FAMILY_PREFIX}${DB_VERSION}.nr90.out.clstr --ids-go-terms-infile ${FAMILY_PREFIX}${DB_VERSION}.ids_go_terms.out --sequences-infile ${FAMILY_PREFIX}${DB_VERSION}.sequences.fa -o starting_clusters/$PROJECT --included-go-iea-terms IEA:UniProtKB-KW,IEA:UniProtKB-EC
fi

# remove all superfamilies with zero starting clusters
# print_date "Finding starting cluster directories with zero or one file(s) to be manually deleted..."
# find $FF_GEN_ROOTDIR/starting_clusters -maxdepth 1 -type d -exec bash -c "echo -ne '{} '; ls '{}' | wc -l" \; | awk '$NF<=1{print "rm -rf " $1}'

# append to a projects.txt file
print_date "Remember to add all non-empty project ids (i.e. superfamily ids) to a projects.txt file"
