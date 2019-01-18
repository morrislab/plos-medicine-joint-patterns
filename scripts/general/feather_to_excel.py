"""
Converts a Feather file to an Excel file.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the Feather file to read input from")
@option("--output", required=True, help="the Excel file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input)

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    X.to_excel(output, index=False)


if __name__ == "__main__":
    main()

