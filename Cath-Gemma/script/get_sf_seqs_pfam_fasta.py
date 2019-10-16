#!/usr/bin/env python3

# core
import argparse
import logging
# include
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord

parser = argparse.ArgumentParser(
    description="Convert a Pfam-A.fasta file to a cleaned up version for Gardener, including a tab file as input for the Luigi pipeline")

parser.add_argument('--in', '-i', type=str, dest='pfam_input_file', required=True,
                    help='PFAM fasta file')

parser.add_argument('--out', '-o', type=str, dest='out_file', required=False,
                    help='output file', default='pfam.valid.fasta')

parser.add_argument('--tab_file', '-tf', type=str, dest='tab_file', required=False,
                    help='tab file', default='Pfam-all.seq')

if __name__ == '__main__':
    args = parser.parse_args()
    pfam_dict = {}
    for record in SeqIO.parse(args.pfam_input_file, "fasta"):
        uniprot_id = record.id.split("_")[0]
        id_boundaries = record.id.split("_")[0]+"/"+record.id.split("/")[1]
        pfam_id = record.description.split(" ")[-1].strip(";")
        sequence = record.seq
        new_record = SeqRecord(sequence, id=id_boundaries,
                               name=record.id, description="")
        pfam_dict[id_boundaries] = new_record
        with open(args.tab_file, "a") as pfam_tab:
            pfam_tab.write(str(uniprot_id+"\t"+id_boundaries +
                               "\t"+pfam_id+"\t"+sequence+"\n"))
    with open(args.out_file, "w") as output_handle:
        SeqIO.write(pfam_dict.values(), output_handle, "fasta")
