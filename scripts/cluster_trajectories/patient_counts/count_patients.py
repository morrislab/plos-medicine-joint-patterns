"""
Counts patients over disease course by patient group.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the CSV file to read group trajectories from")
@option("--output", required=True, help="the CSV file to write counts to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_csv(input)

    debug(f"Result: {X.shape}")

    # Remove localizations.

    info("Removing localizations")

    X["classification"] = X["classification"].str.replace(r"_.+$", "")

    # Count patients.

    info("Counting patients")

    Y = pd.Series(
        X.groupby(["visit_id", "classification"])["subject_id"].agg("count"),
        name="count",
    ).to_frame()

    # Write output.

    info("Writing output")

    Y.to_csv(output)


if __name__ == "__main__":
    main()
