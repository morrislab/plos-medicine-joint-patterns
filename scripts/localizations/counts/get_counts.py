"""
Obtains counts by cluster and localization.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the CSV file to read assignments from")
@option("--output", required=True, help="the CSV file to write counts to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_csv(input)

    debug(f"Result: {X.shape}")

    # Obtain counts.

    info("Obtaining counts")

    counts = pd.Series(
        X.groupby(["classification", "localization"])["subject_id"].count(),
        name="count",
    ).to_frame()

    debug(f"Result: {counts.shape}")

    # Write output.

    info("Writing output")

    counts.to_csv(output)


if __name__ == "__main__":
    main()
