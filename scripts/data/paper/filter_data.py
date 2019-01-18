"""
Filters data for the paper.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--diagnosis-input", required=True, help="the CSV file to read diagnoses from")
@option("--data-input", required=True, help="the Feather file to read data from")
@option("--output", required=True, help="the CSV file to write output data to")
def main(diagnosis_input, data_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading diagnoses")

    diagnoses = pd.read_csv(diagnosis_input, index_col="subject_id")

    debug(f"Result: {diagnoses.shape}")

    info("Loading data")

    X = pd.read_feather(data_input).set_index("subject_id")

    debug(f"Result: {X.shape}")

    # Filter data.

    info("Filtering data")

    X = X.loc[diagnoses.index]

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.to_csv(output)


if __name__ == "__main__":
    main()
