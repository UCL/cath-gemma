#!/usr/bin/env python3

# core
import argparse
import logging
import os
import sys
import re

# include
import utils
from cathpy.version import CathVersion

parser = argparse.ArgumentParser(
    description="Create lookup of UniProtKB-based domains to FunFam ids")

parser.add_argument('--sfam', '-s', type=str, dest='sfam_id', required=True,
    help='superfamily id (eg "3.30.1360.30")')

db_group = parser.add_argument_group('database options')

db_group.add_argument('--cath_version', '-c', type=str, required=True, dest='cath_version',
    help='database name')

parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
    help='more verbose logging')

if __name__ == '__main__':
    args = parser.parse_args()

    utils.init_cli_logging(verbosity=args.verbose)

    cv = CathVersion(args.cath_version)
    tablespace = "cath_v{}".format(cv.join('_'))

    conn = utils.CathOraConnection().conn

    runner = utils.GenerateUniprotFunfamLookup(db_conn=conn, tablespace=tablespace)
    runner.run(args.sfam_id)
    
    conn.close()
