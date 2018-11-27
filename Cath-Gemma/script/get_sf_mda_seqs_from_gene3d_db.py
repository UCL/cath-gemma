#!/usr/bin/env python3

# core
import argparse
import logging
import os
import sys
import re

# include
import cx_Oracle

from . import utils

parser = argparse.ArgumentParser(
    description="Write CATH domain sequences (with MDA info)")

parser.add_argument('--dbname', type=str, default='gene3d_16', dest='tablespace',
    help='database name')

parser.add_argument('--out', '-o', type=str, dest='out_file', required=True,
    help='output file')

parser.add_argument('--sfam', '-s', type=str, dest='sfam_id', required=False,
    help='superfamily id (eg "3.30.1360.30")')

parser.add_argument('--taxon', '-t', type=str, dest='taxon_id', required=False,
    help='taxon id (eg "9606")')

parser.add_argument('--evalue', '-e', type=str, default='0.001', dest='max_evalue',
    help='maximum evalue allowed for predicted CATH domain')

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
        ["tablespace", "max_evalue", "sfam_id", "taxon_id"] }

    dsn=cx_Oracle.makedsn(dbhost, dbport, dbsid)
    conn=cx_Oracle.connect(user=dbuser, password=dbpass, dsn=dsn)

    logger.info("DSN: %s", dsn)

    sfam_id = args.sfam_id

    runner = utils.GenerateMdaSequences(db_conn=conn, **dbargs)

    runner.run()

    logger.info("Getting MDA Summary...")
    mda_summary = runner.get_mda_summary()
    logger.info("Found {} unique MDAs".format(len(mda_summary)) )
    for mda, mda_count in sorted(mda_summary.items(), key=lambda kv: kv[1], reverse=True):
        logger.info("MDA_COUNT {:>7}  {}".format(mda_count, mda))

    logger.info("Writing {} domain sequences to {}".format(runner.count_domains(), args.out_file) )

    runner.write_to_file(args.out_file)

    conn.close()
