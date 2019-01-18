"""
Produces heat map data that describes, for each patient group, the probability
of reaching any other patient group at any time point.
"""

from click import *
from logging import *

import itertools as it
import joblib as jl
import pandas as pd
import tqdm


def get_transition_probability(
    X_reference: pd.DataFrame,
    X_future: pd.DataFrame,
    source_group: str,
    target_group: str,
) -> pd.DataFrame:
    """
    Obtains transition probabilities from a given reference patient group to
    other patient groups at any visit.

    Args:
        X_reference: the reference patient groups
        X_future: the future patient groups
        source_group: the reference patient group
        target_group: the target patient group
    """

    X_reference = (
        X_reference.query("classification == @source_group")
        .drop("visit_id", axis=1)
        .set_index("subject_id")
    )

    X_future = X_future.set_index("subject_id").join(X_reference[[]], how="inner")

    if X_future.shape[0] < 1:

        return None

    X_future = X_future.eval("is_target = (classification == @target_group)")

    future_merged = X_future.groupby("subject_id")["is_target"].max()

    return pd.DataFrame(
        {
            "source": source_group,
            "target": target_group,
            "probability": future_merged.mean(),
            "count": future_merged.sum(),
        },
        index=[0],
    )


@command()
@option(
    "--input",
    required=True,
    metavar="INPUT",
    help="the CSV file to read input data from",
)
@option(
    "--output",
    required=True,
    metavar="OUTPUT",
    help="the CSV file to write output data to",
)
@option(
    "--reference-visit",
    type=IntRange(1),
    default=1,
    show_default=True,
    help="the reference visits to calculate probabilities from",
)
@option("--threads", type=IntRange(1), help="the number of threads")
def main(input, output, reference_visit, threads):

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading data")

    X = pd.read_csv(input)

    debug(f"Result: {X.shape}")

    # Split the data into the reference visit and beyond.

    info("Splitting data")

    X_reference = X.query("visit_id == @reference_visit")

    X_future = X.query("visit_id > @reference_visit")

    # For each reference visit patient group, calculate transition
    # probabilities to other patient groups at any time point.

    info("Calculating transition probabilities")

    reference_groups = sorted(X_reference["classification"].unique())

    future_groups = sorted(X_future["classification"].unique())

    probabilities = pd.concat(
        jl.Parallel(n_jobs=threads)(
            jl.delayed(get_transition_probability)(
                X_reference, X_future, source_group, target_group
            )
            for source_group, target_group in tqdm.tqdm(
                it.product(reference_groups, future_groups),
                total=len(reference_groups) * len(future_groups),
            )
        )
    )

    debug(f"Result: {probabilities.shape}")

    # Write the output.

    info("Writing output")

    probabilities.to_csv(output, index=False)


if __name__ == "__main__":
    main()
