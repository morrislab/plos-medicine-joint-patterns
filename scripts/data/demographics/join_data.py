"""
Joins demographic data together.
"""

from click import *
from logging import *

import functools as ft
import pandas as pd
import pathlib as pl
import tqdm


def load_data(path: str) -> pd.DataFrame:
    """
    Loads data from the given path.

    Renames columns to include the domain.

    Args:
        path: the path to load data from
    """

    info(f"Loading {path}")

    X = pd.read_feather(path).set_index("subject_id")

    debug(f"Result: {X.shape}")

    stem = pl.Path(path).stem

    return X.rename(columns={j: f"{stem}_{j}" for j in X.columns})


@command()
@option(
    "--input", required=True, multiple=True, help="the Feather files to load data from"
)
@option("--output", required=True, help="the Feather file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load and join the data.

    info("Loading and joining data...")

    Xs = (load_data(path) for path in tqdm.tqdm(input))

    X = ft.reduce(ft.partial(pd.DataFrame.join, how="outer"), Xs)

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
