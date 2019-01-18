"""
Extracts information.
"""

from click import *
from logging import *

import click
import pandas as pd
import janitor as jn


@command()
@option("--input", required=True, help="the Excel file to read input data from")
@option("--output", required=True, help="the Feather file to write extracted data to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_excel(input)

    debug(f"Result: {X.shape}")

    # Clean names.

    info("Cleaning names")

    X = X.clean_names(strip_underscores=True).rename(columns={"id": "subject_id"})

    # Convert dates.

    date_columns = [j for j in X.columns if j.endswith("date") or j.startswith("date")]

    if date_columns:

        info("Converting dates")

        for j in date_columns:

            try:

                X[j] = pd.to_datetime(X[j])

            except:

                pass

    # Write output.

    info("Writing data")

    types = X.dtypes

    obj_columns = types[types == object].index.tolist()

    if obj_columns:

        X = X.encode_categorical(obj_columns)

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
