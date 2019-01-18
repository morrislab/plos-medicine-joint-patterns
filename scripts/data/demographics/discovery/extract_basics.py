"""
Extracts all basic patient information.
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

    X = X.clean_names(strip_underscores=True)

    # Convert dates.

    info("Converting dates")

    for j in ["dob", "onset_date_15th", "diagnosis_date"]:

        X[j] = pd.to_datetime(X[j])

    # Calculate age at diagnosis and time to diagnosis.

    info("Calculating age at diagnosis and time to diagnosis")

    X["diagnosis_age"] = (X["diagnosis_date"] - X["dob"]) / pd.to_timedelta(1, "D")

    X["symptom_onset_to_diagnosis"] = (
        X["diagnosis_date"] - X["onset_date_15th"]
    ) / pd.to_timedelta(1, "D")

    # Drop dates.

    info("Dropping dates")

    X = X.drop(["dob", "onset_date_15th", "diagnosis_date"], axis=1)

    # Reformat data.

    info("Reformatting data")

    X["withdrawn"] = X["withdrawn"].fillna(0).astype(bool)

    # Write output.

    info("Writing data")

    types = X.dtypes

    obj_columns = types[types == object].index.tolist()

    if obj_columns:

        X = X.encode_categorical(obj_columns)

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":

    main()
