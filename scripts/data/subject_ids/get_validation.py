"""
Obtains validation subject IDs.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the CSV file to read joint involvements from")
@option("--output", required=True, help="the text file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_csv(input)

    debug(f"Result: {X.shape}")

    # Write output.

    with open(output, "w") as handle:

        handle.write("\n".join(X["subject_id"].astype(str)))


if __name__ == "__main__":
    main()
