"""
Obtain statistics from the permutation test.

As we are testing whether the conditional co-involvement matrices are similar to each
other, we want to conduct a one-sided test. Null hypothesis: observed distance is drawn
from same distribution as random. Alternative hypothesis: observed distance is less than
random distribution.
"""

from click import *
from logging import *

import pandas as pd


def get_p_value(X: pd.DataFrame, base_distances: pd.Series) -> pd.Series:
    """
    Calculates P-values with the given base distances and samples.
    """

    base_distance = base_distances[X["classification"].unique()].squeeze()

    n_samples = X.shape[0]

    n_below = (X["distance"] < base_distance).sum()

    p = n_below / n_samples

    return pd.Series({"samples": n_samples, "below": n_below, "p": p})


@command()
@option(
    "--base-input",
    required=True,
    help="the Feather file to read the base distances from",
)
@option("--sample-input", required=True, help="the Feather file to read samples from")
@option("--output", required=True, help="the Excel file to write output to")
def main(base_input, sample_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading base distances")

    base_distances = pd.read_feather(base_input).set_index("classification")["distance"]

    debug(f"Result: {base_distances.shape}")

    # Load samples.

    info("Loading samples")

    samples = pd.read_feather(sample_input)

    debug(f"Result: {samples.shape}")

    # Calculate P-values.

    info("Calculating P-values")

    Y = samples.groupby("classification").apply(
        get_p_value, base_distances=base_distances
    )

    debug(f"Result: {Y.shape}")

    # Write output.

    info("Writing output")

    Y.to_excel(output)


if __name__ == "__main__":
    main()
