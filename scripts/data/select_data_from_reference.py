"""
Selects data given a reference.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    "--reference-input", required=True, help="the CSV file to read reference data from"
)
@option("--data-input", required=True, help="the CSV file to read input data from")
@option("--output", required=True, help="the CSV file to write output to")
def main(reference_input, data_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading reference data")

    X_reference = pd.read_csv(reference_input, index_col=0)

    debug(f"Result: {X_reference.shape}")

    info("Loading data")

    X = pd.read_csv(data_input, index_col=0)

    debug(f"Result: {X.shape}")

    # Select data.

    info("Selecting data")

    X = X[X_reference.columns]

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.to_csv(output)


if __name__ == "__main__":
    main()
