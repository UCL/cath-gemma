
import argparse
import logging
import os
import sys
import numpy as np
from skbio import DistanceMatrix
from skbio.tree import nj


parser = argparse.ArgumentParser(
    description="Build a newick tree file based on Grantham differneces of sequences",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument('--foldseek_out', '-fso', type=str, dest='foldseek_file', required=True,
                    help='file from the foldseek output')  

parser.add_argument('--names', '-n', type=str, dest='names_file', required=True,
                    help='file containing the names of the proteins')                                                                                                           

parser.add_argument('--output', '-o', type=str, dest='out_file', required=True,
                    help='Name for output difference file')   

parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
                    help='more verbose logging')



if __name__ == '__main__':
    args = parser.parse_args()
    log_level = logging.DEBUG if args.verbose > 0 else logging.INFO
    logging.basicConfig(level=log_level)
    LOGGER = logging.getLogger(__name__)   


    LOGGER.info('Running program')


    fs_list = {}
    with open(args.foldseek_file,'r') as f:
        for line_count,line in enumerate(f):
            line=line.rstrip().split()
            fs_list[(line[0],line[1])] = line[2]

    name_list = []
    with open(args.names_file, "r") as f:
        for line_count,line in enumerate(f):
            name_list.append(line.rstrip())


    with open(args.out_file,'w') as g:
        for i in range(len(name_list)):
            for j in range(i,len(name_list)):
                if name_list[i] == name_list[j]:
                    print(name_list[i],name_list[j],0.0, file=g)
                elif (name_list[i],name_list[j]) in fs_list:
                    print(name_list[i],name_list[j],1/float(fs_list[(name_list[i],name_list[j])]), file=g)
                elif (name_list[j],name_list[i]) in fs_list:
                    print(name_list[i],name_list[j],1/float(fs_list[(name_list[j],name_list[i])]), file=g)
                else:
                    print(name_list[i],name_list[j],0.02, file=g)

  

   