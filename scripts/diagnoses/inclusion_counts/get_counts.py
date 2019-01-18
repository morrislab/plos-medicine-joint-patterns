"""
Obtains category distributions for included and excluded patients.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option("--all-input", required=True, help="the CSV file to read all diagnoses from")
@option(
    "--included-input",
    required=True,
    help="the CSV file to read diagnoses for included patients from",
)
@option("--output", required=True, help="the CSV file to write counts to")
def main(all_input, included_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading all diagnoses")

    X_all = pd.read_csv(all_input, index_col="subject_id").query(
        "diagnosis != 'Withdrawn'"
    )

    debug(f"Result: {X_all.shape}")

    info("Loading diagnoses for included patients")

    X_included = pd.read_csv(included_input, index_col="subject_id")

    debug(f"Result: {X_included.shape}")

    # Obtain diagnoses for excluded patients.

    info("Obtaining diagnoses for excluded patients")

    X_excluded = X_all.drop(X_included.index, axis=0)

    debug(f"Result: {X_excluded.shape}")

    # Generate counts for included and excluded patients.

    info("Generating counts for included patients")

    counts_included = (
        pd.Series(X_included["diagnosis"].value_counts(), name="count")
        .reset_index()
        .rename(columns={"index": "diagnosis"})
    )

    counts_included["frequency"] = (
        counts_included["count"] / counts_included["count"].sum()
    )

    counts_included["criteria"] = "included"

    counts_excluded = (
        pd.Series(X_excluded["diagnosis"].value_counts(), name="count")
        .reset_index()
        .rename(columns={"index": "diagnosis"})
    )

    counts_excluded["frequency"] = (
        counts_excluded["count"] / counts_excluded["count"].sum()
    )

    counts_excluded["criteria"] = "excluded"

    counts = pd.concat([counts_included, counts_excluded])

    debug(f"Result: {counts.shape}")

    # Write output.

    info("Writing output")

    counts.to_csv(output, index=None)


if __name__ == "__main__":
    main()
