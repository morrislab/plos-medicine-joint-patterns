"""
Concatenates joint involvement data.
"""

from click import *
from logging import *

import pandas as pd


def load_data(path: str, visit: int) -> pd.DataFrame:
    """
    Loads data for the given visit.

    Args:
        path: the path to the data
        visit: the visit number
    """

    info(f"Loading {path}")

    X = pd.read_csv(path)

    X["visit_id"] = visit

    debug(f"Result: {X.shape}")

    return X


@command()
@option(
    "--input",
    required=True,
    multiple=True,
    help="the CSV files to read input data from",
)
@option(
    "--visit",
    type=IntRange(1),
    required=True,
    multiple=True,
    help="the visit numbers corresponding to the inputs",
)
@option("--output", required=True, help="the Feather file to write output to")
def main(input, visit, output):

    if len(input) != len(visit):

        raise Exception("number of --inputs must match number of --visits")

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading and concatenating data...")

    X = pd.concat(load_data(path, v) for path, v in zip(input, visit))

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
