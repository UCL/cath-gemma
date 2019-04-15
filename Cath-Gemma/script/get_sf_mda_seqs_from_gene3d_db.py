#!/usr/bin/env python3

# core
import argparse
import logging
import os
import sys
import re

# include
import cx_Oracle

import utils

DEFAULT_DB_NAME='gene3d_16'
DEFAULT_MIN_EVALUE=0.001
DEFAULT_MIN_PARTITION_SIZE=100

parser = argparse.ArgumentParser(
    description="Write CATH domain sequences (with MDA info)")

output_group = parser.add_mutually_exclusive_group(required=True)

output_group.add_argument('--out', '-o', type=str, dest='out_file', required=False,
    help='output file')

output_group.add_argument('--basedir', type=str, default=None, dest='base_dir', required=False,
    help='base directory')

parser.add_argument('--nopartition', default=False, action='store_true',
    help='do not partition the sequences by MDA')

filter_group = parser.add_argument_group('filter options')

filter_group.add_argument('--sfam', '-s', type=str, dest='sfam_id', required=False,
    help='superfamily id (eg "3.30.1360.30")')

filter_group.add_argument('--taxon', '-t', type=str, dest='taxon_id', required=False,
    help='taxon id (eg "9606")')

db_group = parser.add_argument_group('database options')

db_group.add_argument('--dbname', type=str, default=DEFAULT_DB_NAME, dest='tablespace',
    help='database name')

db_group.add_argument('--evalue', '-e', type=str, default=DEFAULT_MIN_EVALUE, dest='max_evalue',
    help='maximum evalue allowed for predicted CATH domain')

db_group.add_argument('--maxrows', type=int, required=False, dest='max_rows', default=None,
    help='limit the number of rows returned (only useful to speed up testing)')

db_group.add_argument('--minpartition', type=int, default=DEFAULT_MIN_PARTITION_SIZE, dest='min_partition_size',
    help='min number of sequences that a MDA must have before creating a new partition')

parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
    help='more verbose logging')

if __name__ == '__main__':
    args = parser.parse_args()

    log_level = logging.DEBUG if args.verbose > 0 else logging.INFO
    logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%y %H:%M:%S', level=log_level)
    logger = logging.getLogger(__name__)

    # https://gist.github.com/kimus/10012910

    dbuser="orengoreader"
    dbpass="orengoreader"
    dbhost="odb.cs.ucl.ac.uk"
    dbport=1521
    dbsid='cathora1'

    # 1.get all the uniprot accessions involved in this superfamily
    #
    # 2. for all of these uniprot accessions:
    #   - get all the cath domain predictions
    #   - get all the pfam domains?
    #
    # 3. build mda

    # TODO: sort out a proper ORM to avoid hard-coded SQL
    #       for the moment, it's encapsulated in functions..

    dbargs = { n: getattr(args, n) for n in 
        ["tablespace", "max_evalue", "min_partition_size", "sfam_id", "taxon_id", "max_rows", "nopartition"] }

    dsn=cx_Oracle.makedsn(dbhost, dbport, dbsid)
    conn=cx_Oracle.connect(user=dbuser, password=dbpass, dsn=dsn)

    logger.info("DSN: %s", dsn)

    logger.debug("ARGS: %s", dbargs)
    runner = utils.GenerateMdaSequences(db_conn=conn, **dbargs)

    runner.run()

    logger.info("Getting MDA Summary...")
    mda_summary = runner.get_mda_summary()
    logger.info("Found {} unique MDAs".format(len(mda_summary)) )
    
    if args.base_dir:
        logger.info("Creating project files in %s ...", args.base_dir)
        runner.write_project_files(args.base_dir)
    else:
        logger.info("Writing {} domain sequences to {}".format(runner.count_domains(), args.out_file))
        runner.write_to_file(args.out_file)

    conn.close()
