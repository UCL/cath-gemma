#!/usr/bin/env python
import argparse
import logging
import os
# import sys
from Bio import SeqIO
import matplotlib.pyplot as plt
import numpy as np

# This script follows the formula from the following manuscript from the Sjolander group:
# "Automated Protein Subfamily Identification and Classification"
# PLoS Computational Biology 3(8),e160 (2007)
#https://doi.org/10.1371/journal.pcbi.0030160

# The --funfam_folder should be a single folder containing all .aln files from FunFhmmer
# The --ec_input should consist of two columns being seqeunce name and EC number, e.g.:
# seq1 1.3.4.2
# seq2 1.3.4.4 

parser = argparse.ArgumentParser(
    description="Get the FunFam quality based on UniProt EC number IDs for them.",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument('--funfam_folder', '-ff', type=str, dest='ff_folder', required=True,
                    help='Folder containing all the FunFams from FunFhmmer')

parser.add_argument('--ec_input', '-ec', type=str, dest='inp_ec', required=True,
                    help='File containing the EC numbers for the sequences')  

parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
                    help='more verbose logging')


class ec_number:
    def __init__(self, number, level):
        self.number = number
        self.up_ids = set()
        self.up_ids_all = list()
        self.funfams = set()
        self.level = level
        
    def add_up(self,up_id):
        self.up_ids.add(up_id)

    def add_up_all(self,up_id):
        self.up_ids_all.append(up_id)    

    def add_funfam(self,funfam):
        self.funfams.add(funfam)    


class funfam_ref:
    def __init__(self, name, ecnum):
        self.name = name 
        self.ecnum = ecnum
        self.ec_nums = list()
        self.up_ids = list()


    def add_up_id(self,up_id):
        self.up_ids.append(up_id)

    def add_ec(self,ecnum):
        self.ec_nums.append(ecnum)


class funfam_0:
    def __init__(self,ec_num):
        self.ec_num = ec_num
        self.up_ids = list()

    def add_up_id(self,up_id):
        self.up_ids.append(up_id)

class funfam:
    def __init__(self, name):
        self.name = name 
        self.ec_nums = list()
        self.up_ids = list()

    def add_up_id(self,up_id):
        self.up_ids.append(up_id)


    def add_ec(self,ec_num):
        self.ec_nums.append(ec_num)


def get_edit_distance(ffs,ref_ffs):
    edit_distance = 0
    for ff in ffs:
        for ref_ff in ref_ffs:
            if bool(set(ff.up_ids) & set(ref_ff.up_ids)):
                edit_distance += 2

    edit_distance -= len(ffs)
    edit_distance -= len(ref_ffs)

    return edit_distance


def get_entropy(ffs,total_num):
    entropy = 0.0
    for ff in ffs:
        entropy += len(ff.up_ids)/total_num*np.log(len(ff.up_ids)/total_num)
    return entropy


def get_mutual_information(ffs,ref_ffs,total_num):
    mi = 0.0
    for ff in ffs:
        for ref_ff in ref_ffs:
            k_ff_refff = 0
            for up in ref_ff.up_ids:
                if up in ff.up_ids:
                    k_ff_refff += 1
            if k_ff_refff > 0:
                mi += k_ff_refff/total_num*np.log(k_ff_refff/total_num)
    return mi

def get_vi_distance(ffs,ref_ffs):

    total_num = 0
    for ff in ref_ffs:
        total_num += len(ff.up_ids)
  
    entropy_ffs = get_entropy(ffs,total_num)
    entropy_ref_ffs = get_entropy(ref_ffs,total_num)

    mutual_information = get_mutual_information(ffs,ref_ffs,total_num)

    return entropy_ffs + entropy_ref_ffs - 2 * mutual_information


def get_purity(ffs):

    num_pure = 0
    for ff in ffs:
        if len(set(ff.ec_nums)) == 1:
            num_pure += 1

    return num_pure / len(ffs)

if __name__ == '__main__':
    args = parser.parse_args()
    log_level = logging.DEBUG if args.verbose > 0 else logging.INFO
    logging.basicConfig(level=log_level)
    LOGGER = logging.getLogger(__name__)   


    LOGGER.info('Running program')

    # Read the EC values for all proteins and set up the classes
    all_ecs4 = []
    all_ecs3 = []
    all_ffs_0 = []
    with open(args.inp_ec, 'r') as f:
        for line_count,line in enumerate(f):
            line=line.rstrip().split()
            up = line[0]
            new_ff_0 = funfam_0(line[1])
            new_ff_0.add_up_id(line[0])
            all_ffs_0.append(new_ff_0)
            ecs= line[1].split(';')
            for ec_num in ecs:
                known_ec4 = False
                for entry in range(len(all_ecs4)):
                    if all_ecs4[entry].number == ec_num:
                        all_ecs4[entry].add_up(up)
                        all_ecs4[entry].add_up_all(up)
                        known_ec4=True
                if known_ec4 == False:
                    new_ec = ec_number(ec_num, 4)
                    new_ec.add_up(up)
                    new_ec.add_up_all(up)
                    all_ecs4.append(new_ec)



    # Get the pure reference FunFams
    all_ffs_ref = []
    for ec in all_ecs4:
        new_ff = funfam_ref(ec.number,ec.number)
        for up_id in ec.up_ids_all:
            new_ff.add_up_id(up_id) 
        all_ffs_ref.append(new_ff)

    # Read through all FunFam files and generate their classes. 
    # Fill up all the FunFam/EC information
    all_ffs = []
    for ff_file in os.listdir(args.ff_folder):
        if ff_file.endswith(".aln"):
            ff_name = ff_file[:-4]
            ff = funfam(ff_name)
            has_ec = False
            with open(args.ff_folder+'/'+ff_file, 'r') as f:
                for line_count,line in enumerate(f):
                    if line.startswith('>'):
                        seqnum = line.split('/')[0][1:]
                        for ec in all_ecs4:
                            if seqnum in ec.up_ids:
                                ec.add_funfam(ff_name)
                                ff.add_up_id(seqnum)
                                ff.add_ec(ec.number)
                                has_ec = True
            if has_ec:
                all_ffs.append(ff)


    purity = get_purity(all_ffs)

    ed = get_edit_distance(all_ffs,all_ffs_ref)
    vi = get_vi_distance(all_ffs,all_ffs_ref)

    ed_0 = get_edit_distance(all_ffs_0,all_ffs_ref)
    vi_0 = get_vi_distance(all_ffs_0,all_ffs_ref)

    performance = (2*purity*100 + (100 - 100/ed_0*ed) + (100 - 100/vi_0*vi)) / 4

    print('Purity =',purity*100)
    print('Performance =',performance)