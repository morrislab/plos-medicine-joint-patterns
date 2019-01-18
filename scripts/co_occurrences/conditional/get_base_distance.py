"""
Obtains base distances.
"""

from click import *
from logging import *

import math
import pandas as pd


def get_distance(X: pd.DataFrame) -> float:
    """
    Obtains a distance between two matrices encoded by the data frame.

    Args:
        X: the data frame
    """

    x_left = X.loc[X["reference_side"] == "left"].set_index(
        ["reference_root", "co_occurring_root"]
    )["conditional_probability"]

    x_right = X.loc[X["reference_side"] == "right"].set_index(
        ["reference_root", "co_occurring_root"]
    )["conditional_probability"]

    return math.sqrt(((x_left - x_right) ** 2).sum())


@command()
@option("--input", required=True, help="the Feather file to load input data from")
@option("--output", required=True, help="the Feather file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input)

    debug(f"Result: {X.shape}")

    # Get distances.

    info("Getting distances")

    y = pd.Series(X.groupby("classification").apply(get_distance), name="distance")

    debug(f"Result: {y.shape}")

    # Write output.

    info("Writing output")

    y.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
