"""
Extracts all medication information from the validation cohort.
"""

from click import *
from logging import *

import collections
import pandas as pd


COLUMNS = collections.OrderedDict(
    [
        ("ID", "subject_id"),
        ("TIMEFRAME", "visit_id"),
        ("IAS", "joint_injection"),
        ("NSAID", "nsaid"),
        ("DMARD", "dmard"),
        ("BIOLOGIC", "biologic"),
        ("CORTICOSTEROIDS", "steroid"),
    ]
)


@command()
@option("--input", required=True, help="the Excel file to load input data from")
@option("--output", required=True, help="the Feather file to write extracted data to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading data")

    X = pd.read_excel(input)

    debug(f"Result: {X.shape}")

    # Select data.

    info("Selecting data")

    X = X[list(COLUMNS.keys())].rename(columns=COLUMNS)

    debug(f"Result: {X.shape}")

    # Output the resulting data.

    info("Writing data")

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
