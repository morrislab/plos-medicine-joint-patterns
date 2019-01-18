"""
Obtains discovery data subject IDs.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the CSV file to load the patient filter from")
@option("--output", required=True, help="the text file to write output to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading filter")

    X = pd.read_csv(input, index_col="subject_id")

    debug(f"Result: {X.shape}")

    # Filter the filter.

    info("Filtering filter")

    X = X.query("all_combined == True")

    debug(f"Result: {X.shape}")

    # Write output.

    info("Writing output")

    with open(output, "w") as handle:

        handle.write("\n".join(X.index.astype(str)))


if __name__ == "__main__":
    main()
