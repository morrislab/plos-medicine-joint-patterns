"""
Annotates co-occurrences.
"""

from click import *
from logging import *

import janitor as jn
import pandas as pd


@command()
@option("--input", required=True, help="the Feather file to read input data from")
@option("--output", required=True, help="the Feather file to write annotated data to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input)

    debug(f"Result: {X.shape}")

    # Select data.

    info("Selecting data")

    X = X[
        [
            "classification",
            "reference_site",
            "co_occurring_site",
            "conditional_probability",
        ]
    ]

    debug(f"Result: {X.shape}")

    # Filter out unpaired joints.

    info("Removing unpaired joints")

    X = X.loc[
        X["reference_site"].str.contains(r"_(left|right)$")
        & X["co_occurring_site"].str.contains(r"_(left|right)$")
    ]

    debug(f"Result: {X.shape}")

    # Add annotations.

    info("Adding annotations")

    X_reference = (
        X["reference_site"]
        .str.extract(r"^(.+?)_(left|right)$")
        .rename(columns={0: "reference_root", 1: "reference_side"})
    )

    X_co_occurring = (
        X["co_occurring_site"]
        .str.extract(r"^(.+?)_(left|right)$")
        .rename(columns={0: "co_occurring_root", 1: "co_occurring_side"})
    )

    X = (
        X.drop(["reference_site", "co_occurring_site"], axis=1)
        .join(X_reference)
        .join(X_co_occurring)
    )

    # Write output.

    info("Writing output")

    X = X.encode_categorical(
        ["reference_root", "reference_side", "co_occurring_root", "co_occurring_side"]
    )

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
