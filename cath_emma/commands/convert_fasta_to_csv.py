import click
from Bio import SeqIO

@click.command()
@click.option(
    '-i',
    '--input_file',
    type=click.Path(exists=True),
    required=True, 
    help='Input multiFASTA file'
    )
@click.option(
    '-o',
    '--output_file',
    type=click.Path(),
    required=True,
    help='Output comma-separated file sequence file for embedding generation')

def convert_fasta_to_csv_for_embed(input_file, output_file):
    """Convert a (multi)FASTA file into a csv file for embedding generation"""
    records = SeqIO.parse(input_file, 'fasta')
    with open(output_file, 'w') as f:
        for record in records:
            f.write(f'{record.id},{str(record.seq)}\n')
