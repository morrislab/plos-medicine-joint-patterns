"""
Filters data to subject IDs of interest.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--data-input", required=True, help="the Feather file to read input data from")
@option(
    "--subject-id-input",
    type=File("rU"),
    required=True,
    help="the text file to read subject IDs from",
)
@option("--output", required=True, help="the Feather file to write output data to")
def main(data_input, subject_id_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(data_input).set_index("subject_id")

    debug(f"Result: {X.shape}")

    info("Loading subject IDs")

    subject_ids = [int(x) for x in subject_id_input]

    debug(f"Result: {len(subject_ids)} entries")

    # Filter data to baseline.

    if "timeframe" in X.columns:

        info("Filtering data to baseline")

        X = X.query("timeframe == 1")

        debug(f"Result: {X.shape}")

    elif "visit_id" in X.columns:

        info("Filtering data to baseline")

        X = X.query("visit_id == 1")

        debug(f"Result: {X.shape}")

    # Drop obviously unhelpful columns.

    info("Dropping extra columns")

    columns_to_drop = [
        j for j in ["centre", "visit_id", "visit_date"] if j in X.columns
    ]

    X = X.drop(columns_to_drop, axis=1)

    debug(f"Result: {X.shape}")

    # Filter data.

    info("Filtering data")

    X = X.reindex(subject_ids)

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
