"""
Cleans demographic data.
"""

from click import *
from logging import *

import numpy as np
import pandas as pd


def clean_vector(x: pd.Series) -> pd.Series:
    """
    Cleans the given vector of placeholder NA values.

    These values include 8888 and 9999.

    Args:
        x: values to clean
    """

    if pd.api.types.is_numeric_dtype(x):

        return pd.Series(
            np.where(x.isin([8888, 9999, 8888.88, 9999.99]), np.nan, x), index=x.index
        )

    return x


@command()
@option("--input", required=True, help="the Feather file to read data from")
@option("--output", required=True, help="the Feather file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input).set_index("subject_id")

    debug(f"Result: {X.shape}")

    # Clean the data.

    info("Cleaning data")

    X = X.apply(clean_vector)

    # Write output.

    info("Writing output")

    X.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
