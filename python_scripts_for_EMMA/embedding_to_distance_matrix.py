import argparse
import logging
import numpy as np


parser = argparse.ArgumentParser(
    description="Generate a distance matrix file for ProtT5 embeddings",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument('--embed', '-e', type=str, dest='embed_file', required=True,
                    help='npz file from embedding')  

parser.add_argument('--names', '-n', type=str, dest='names_file', required=True,
                    help='file containing the names in the same order as the embedding file')  

parser.add_argument('--subset', '-s', type=str, dest='subset_file', required=False,
                    help='file containing the names of the embeddings you want in the tree')  

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


    embed_list = []
    embed = np.load(args.embed_file)
    for i in range(len(embed["arr_0"])):
        embed_list.append(embed["arr_0"][i])

    print("loaded embs")


    name_list = []
    with open(args.names_file, "r") as f:
        for line_count,line in enumerate(f):
            name_list.append(line.rstrip())

    print("loaded names")


    # If you do not want to create output for all files in the embedding you can
    # define a subset with the --subset file.
    if args.subset_file:
        embed_names = []
        with open(args.subset_file, "r") as f:
            for line_count,line in enumerate(f):
                embed_names.append(line.rstrip())

        embed_tree = []
        for i in range(len(name_list)):
            if name_list[i] in embed_names:
                embed_tree.append(embed_list[i])
    else:
        embed_tree = embed_list
        embed_names = name_list


    # Print only the upper triangle distance matrix
    with open(args.out_file, 'w') as g:
        for i in range(len(embed_tree)):
            for j in range(i,len(embed_tree)):
                print(embed_names[i],embed_names[j],np.linalg.norm(embed_tree[i]-embed_tree[j]), file=g)

   
   