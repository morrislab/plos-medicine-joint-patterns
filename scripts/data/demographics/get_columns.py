"""
Obtains column names.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the Feather file to read input from")
@option("--output", required=True, help="the text file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(input)

    debug(f"Result: {X.shape}")

    columns = sorted(X.columns)

    # Write output.

    info("Writing output")

    with open(output, "w") as handle:

        handle.write("\n".join(columns))


if __name__ == "__main__":
    main()
