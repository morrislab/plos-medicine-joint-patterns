"""
Aligns data with discovery cohort data.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    "--validation-input",
    required=True,
    help="the Feather file to load validation cohort data from",
)
@option(
    "--discovery-input",
    required=True,
    help="the Feather file to load discovery cohort data from",
)
@option("--output", required=True, help="the Feather file to write aligned data to")
def main(validation_input, discovery_input, output):

    basicConfig(level=DEBUG)

    # Load validation data.

    info("Loading validation data")

    X_validation = pd.read_feather(validation_input).set_index(
        ["subject_id", "visit_id"]
    )

    debug(f"Result: {X_validation.shape}")

    info("Loading discovery data")

    X_discovery = pd.read_feather(discovery_input).set_index(["subject_id", "visit_id"])

    debug(f"Result: {X_discovery.shape}")

    # Align the data.

    info("Aligning data")

    missing_columns_validation = X_discovery.columns.difference(X_validation.columns)

    missing_columns_discovery = X_validation.columns.difference(X_discovery.columns)

    for j in missing_columns_validation:

        X_validation[j] = 0

    X_validation = X_validation.drop(missing_columns_discovery, axis=1)

    X_validation = X_validation[X_discovery.columns]

    debug(f"Result: {X_validation.shape}")

    # Write output.

    info("Writing output")

    X_validation.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
