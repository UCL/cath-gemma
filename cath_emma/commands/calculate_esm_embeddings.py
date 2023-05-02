import pandas as pd
import esm
import torch
import click
from torch.utils.data import DataLoader, Dataset
from tqdm import tqdm
import os

@click.command()
@click.option(
    "--input_sequence_csv",
    type=click.File("rt"),
    required=True,
    help="Input: CSV file containing protein sequences in the format 'label,sequence'",
)
@click.option(
    "--esm_model",
    type=click.Choice(["esm1v","esm1b","esm2_3b","esm2","esm2_15b"]),
    default="esm2",
    help=f"ESM model used to generate embeddings (default: ESM2)",
)
@click.option(
    "--embeddings_output",
    type=click.File("wt"),
    required=True,
    help=f"Output: Torch .pt file with embeddings",
)
@click.option(
    "--batch_size",
    type=int,
    default=2,
    help=f"Change value to determine how many embeddings to generate for each round (default: 2).",
)
def calculate_esm_to_embed(input_sequence_csv, esm_model, embeddings_output):
    """Calculate embeddings for an input csv file containing sequences and labels using ESM2"""
    if torch.cuda.is_available():
        SEED = 2023
        device = torch.device("cuda")
        torch.cuda.manual_seed(SEED)
        print(f'There are {torch.cuda.device_count()} GPU(s) available.')
        print('Device name:', torch.cuda.get_device_name(0))
    else:
        print('No GPU available, using the CPU instead.')
    device = torch.device("cpu")
    path_to_csv = input_sequence_csv
    output_path = embeddings_output

    if not os.path.exists(os.path.join(output_path)):
        os.makedirs(os.path.join(output_path), exist_ok=True)

    df = pd.read_csv(path_to_csv,names=['label','sequence'])

    batch_size = 2 # you can change here to determine how many embeddings to generate for each round.

    model_selection = esm_model

    if model_selection =='esm1v':
        model, alphabet = esm.pretrained.esm1v_t33_650M_UR90S_1() # can run on 12GB GPU
    elif model_selection == 'esm1b':
        model, alphabet = esm.pretrained.esm1b_t33_650M_UR50S() # can run on 12GB GPU
    elif model_selection == 'esm2':
        model, alphabet = esm.pretrained.esm2_t33_650M_UR50D() # can run on 12GB GPU
    elif model_selection == "esm2_3b":
        model, alphabet = esm.pretrained.esm2_t36_3B_UR50D() # can run on 24GB GPU
    elif model_selection == "esm2_15b":
        model, alphabet = esm.pretrained.esm2_t48_15B_UR50D() # not possible to run on the cluster, too large

    batch_converter = alphabet.get_batch_converter()
    model = model.to(device) # move the model to GPU

    dataset = ESMDataset(df)
    data_loader = DataLoader(dataset, batch_size=batch_size, shuffle=False,collate_fn=collate_fn, drop_last=False)

    
    embeddings = []
    for i in tqdm(data_loader):
        batch_labels, batch_strs, batch_tokens = batch_converter(i)
        with torch.no_grad():
            results = model(batch_tokens.to(device), repr_layers=[33])["representations"][33] # batch_size, max_seq_len, embedding_size
            avg_x = torch.mean(results, dim=1) # average the embedding for each sequence -> batch_size, embedding_size
            for j in range(len(batch_labels)):
                embeddings.append({'label': batch_labels[j], 'mean_representations': {33: avg_x[j]}})


    # save the embeddings
    torch.save(embeddings,embeddings_output) # length of the dataset, embedding_size, e.g. (140000, 1280)




# prepare dataset for ESM
class ESMDataset(Dataset):
    def __init__(self,row):
        super().__init__()
        self.seq = row['sequence']
        self.label = row['label']
    def __len__(self):
        return len(self.seq)
    def __getitem__(self, idx):
        return (self.label[idx],self.seq[idx])
    
def collate_fn(batch):
    labels, sequences = zip(*batch)
    return list(zip(labels, sequences))


