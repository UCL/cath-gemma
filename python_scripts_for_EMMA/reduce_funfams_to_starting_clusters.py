import argparse
import logging
import os
from Bio import SeqIO


parser = argparse.ArgumentParser(
    description="Fill up the Gemma Tree alignment directories",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument('--funfamdir', '-ffd', type=str, dest='funfamdir', required=True,
                    help='Directory of the FunFams')  

parser.add_argument('--clusterfile', '-cf', type=str, dest='cluster_file', required=True,
                    help='file containing the clusters')                   

parser.add_argument('--sequences', '-seqs', type=str, dest='seqfile', required=False,
                    help='file containing all of the sequences')  

parser.add_argument('--out_sc', '-o', type=str, dest='out_sc', required=True,
                    help='Folder for the new starting clusters')                                                                                                           
parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
                    help='more verbose logging')

# This script reduces FunFams to just their starting clusters. The names for the 
# new starting clusters are working_XX.aln. You can use this script sequentially
# on several sets of FunFam folders as the numbering of XX will continuously go up.


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



    # Load up cluster info
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
    
    # redo all the cluster files

    os.makedirs(args.out_sc, exist_ok=True)

    # Get the number of starting clusters already present in the directroy
    scnum=1
    for scfile in os.listdir(args.out_sc):
        scnum+=1
        
    for funfam_file in os.listdir(args.funfamdir):
        if funfam_file.endswith('.aln'):
            scnum+=1
            with open(args.funfamdir+'/'+funfam_file,'r') as f:
                with open(args.out_sc+'/working_'+str(scnum)+'.faa','w') as g:
                    for line_count,line in enumerate(f):
                        if line.startswith('>'):
                            for clust in allclusts:
                                if clust.center == line.rstrip()[1:]:
                                    print('>'+allseqs[clust.center].description, file=g)
                                    print(str(allseqs[clust.center].seq).replace("-",""),file=g)
