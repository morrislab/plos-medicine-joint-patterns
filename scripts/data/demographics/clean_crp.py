"""
Cleans CRP data.
"""

from click import *
from logging import *

import numpy as np
import pandas as pd
import re

BAD_PATTERNS = "|".join(
    [r"\d+-\d+", r"\d+,\s+>\d+\s*<?\d+$", r"\d+:\d+", r"[<>]\d*\.\d+", r"[<>]\d+"]
)
BAD_PATTERNS = f"^{BAD_PATTERNS}$"


def clean_crp(x: str) -> float:
    """
    Cleans a CRP value and converts it to a float.

    Args:
        x: the value
    """

    if pd.isnull(x) or re.match(BAD_PATTERNS, x):

        return np.nan

    if "neg" in x.lower():

        return 0

    return float(x)


@command()
@option("--input", required=True, help="the Feather file to load data from")
@option("--output", required=True, help="the Feather file to write data to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input).set_index("subject_id")

    debug(f"Result: {X.shape}")

    # Clean the CRP column.

    info("Cleaning CRP column")

    X["crp_res"] = X["crp_res"].apply(clean_crp)

    # Write output.

    info("Writing output")

    X.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
