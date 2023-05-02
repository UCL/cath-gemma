import logging
import click

from .commands import calculate_esm_embeddings
from .commands import convert_fasta_to_csv

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s"
)

LOG = logging.getLogger(__name__)

@click.group()
@click.version_option()
@click.option("--verbose", "-v", "verbosity", default=0, count=True)
@click.pass_context
def cli(ctx, verbosity):
    "CATH-eMMA WorkFlow"

    root_logger = logging.getLogger()
    log_level = root_logger.getEffectiveLevel() - (10 * verbosity)
    root_logger.setLevel(log_level)
    LOG.info(
        f"Starting logging... (level={logging.getLevelName(root_logger.getEffectiveLevel())})"
    )

cli.add_command(calculate_esm_embeddings.calculate_esm_to_embed)
cli.add_command(convert_fasta_to_csv.convert_fasta_to_csv_for_embed)