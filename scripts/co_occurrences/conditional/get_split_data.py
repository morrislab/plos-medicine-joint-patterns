"""
Obtains data for a side pairing.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the Feather file to read input data from")
@option("--output", required=True, help="the Feather file to write output to")
@option(
    "--sides",
    type=Choice(["same", "opposite"]),
    required=True,
    help="the sides to consider",
)
def main(input, output, sides):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input)

    debug(f"Result: {X.shape}")

    # Filter the data.

    info("Filtering data")

    if sides == "same":

        X = X.loc[X["reference_side"] == X["co_occurring_side"]]

    else:

        X = X.loc[X["reference_side"] != X["co_occurring_side"]]

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
