import argparse
import logging
import os
import sys
import numpy as np
from Bio import SeqIO
from subprocess import call


parser = argparse.ArgumentParser(
    description="Fill up the Gemma Tree alignement directories",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument('--treedir', '-td', type=str, dest='treedir', required=True,
                    help='Directory of the tree')  

parser.add_argument('--clusterfile', '-cf', type=str, dest='cluster_file', required=True,
                    help='file containing the clusters')                   

parser.add_argument('--sequences', '-seqs', type=str, dest='seqfile', required=True,
                    help='file containing all of the sequences')  

parser.add_argument('--out_tree', '-o', type=str, dest='out_tree', required=True,
                    help='Folder for the new enhanced tree')                                                                                                           
parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
                    help='more verbose logging')


class Starting_clust:
    def __init__(self,clust_id):
        self.id = clust_id
        self.seqs = set()
        self.center = ''

    def add_seq(self,seqid):
        self.seqs.add(seqid)

    def add_center(self,seqid):
        self.seqs.add(seqid)
        self.center = seqid



if __name__ == '__main__':
    args = parser.parse_args()
    log_level = logging.DEBUG if args.verbose > 0 else logging.INFO
    logging.basicConfig(level=log_level)
    LOGGER = logging.getLogger(__name__)   


    LOGGER.info('Running program')

    allseqs = SeqIO.index(args.seqfile, "fasta")

    # Load up cluster info. This tells us which sequences are in each cluster
    allclusts = []
    with open(args.cluster_file, 'r') as f:
        for line_count,line in enumerate(f):
            line=line.rstrip().split()
            if line[0].startswith('>'):
                try:
                    allclusts.append(curr_clust)
                except:
                    LOGGER.debug('no')
                curr_clust = Starting_clust(line[1])
            else:
                if line[3] == '*':
                    curr_clust.add_center(line[2][1:][:-3])
                else:
                    curr_clust.add_seq(line[2][1:][:-3])
        allclusts.append(curr_clust)
    
    # redo files

    os.makedirs(args.out_tree+'/starting_cluster_alignments/', exist_ok=True)
    os.makedirs(args.out_tree+'/merge_node_alignments/', exist_ok=True)

    # copy the newick and trace files
    call([f'cp {args.treedir}/tree* {args.out_tree}/' ], shell=True)



    # Go through all starting cluster files
    for alignment_file in os.listdir(args.treedir+'/starting_cluster_alignments/'):
        # Get all the clusters in the file
        with open(args.out_tree+'/starting_cluster_alignments/'+alignment_file,'w') as g:
            with open(args.treedir+'/starting_cluster_alignments/'+alignment_file,'r') as f:
                for line_count,line in enumerate(f):
                    if line.startswith('>'):
                        for clust in allclusts:
                            if line.rstrip()[1:] in clust.seqs:
                                for seq_to_add in clust.seqs:
                                    print('>'+allseqs[seq_to_add].description, file=g)
                                    print(allseqs[seq_to_add].seq,file=g)


    # Go through all merge node files
    for alignment_file in os.listdir(args.treedir+'/merge_node_alignments/'):
        # Get all the clusters in the file
        with open(args.out_tree+'/merge_node_alignments/'+alignment_file,'w') as g:
            with open(args.treedir+'/merge_node_alignments/'+alignment_file,'r') as f:
                for line_count,line in enumerate(f):
                    if line.startswith('>'):
                        for clust in allclusts:
                            if line.rstrip()[1:] in clust.seqs:
                                for seq_to_add in clust.seqs:
                                    print('>'+allseqs[seq_to_add].description, file=g)
                                    print(allseqs[seq_to_add].seq,file=g)
