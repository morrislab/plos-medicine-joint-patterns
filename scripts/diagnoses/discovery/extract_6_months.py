"""
Extracts six-month diagnoses.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--input", required=True, help="the CSV file to load diagnoses from")
@option("--output", required=True, help="the CSV file to write six-month diagnoses to")
def main(input, output):

    basicConfig(level=DEBUG)

    # Load diagnoses.

    info("Loading diagnoses")

    diagnoses = pd.read_csv(input, index_col="subject_id")[
        ["diagnosis_6_months"]
    ].rename(columns={"diagnosis_6_months": "diagnosis"})

    debug(f"Result: {diagnoses.shape}")

    # Split diagnoses.

    info("Splitting diagnoses")

    diagnoses = (
        diagnoses["diagnosis"]
        .str.extract(r"^(.+?)(\s+\((.+?)\))?$", expand=True)
        .drop(1, axis=1)
        .rename(columns={0: "diagnosis", 2: "subdiagnosis"})
    )

    diagnoses["subdiagnosis"] = diagnoses["subdiagnosis"].str.capitalize()

    debug(f"Result: {diagnoses.shape}")

    # Write output.

    info("Writing output")

    diagnoses.to_csv(output)


if __name__ == "__main__":
    main()
