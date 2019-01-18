"""
Obtains permutation samples of distances.
"""

from click import *
from logging import *

import joblib as jl
import numpy as np
import pandas as pd
import tqdm

from sklearn.utils import shuffle


def do_permutation(X: pd.DataFrame) -> float:
    """
    Conducts a single permutation test for a single number of groups.

    Args:
        X: probabilities for each reference site for the group
    """

    x_a = X["conditional_probability_a"].values

    x_b = shuffle(X["conditional_probability_b"].values)

    return np.sqrt(((x_a - x_b) ** 2).sum())


def do_permutation_test(X: pd.DataFrame, seed: int) -> pd.DataFrame:
    """
    Conducts permutation tests on the given data.

    Args:
        X: probabilities for each reference site
        seed: the seed
    """

    np.random.seed(seed)

    Y = pd.Series(
        X.groupby("classification").apply(do_permutation), name="distance"
    ).reset_index()

    Y["seed"] = seed

    return Y


@command()
@option(
    "--data-input",
    required=True,
    help="the Feather file to read conditional probabilities from",
)
@option("--seed-input", type=File("rU"), required=True, help="the seeds to use")
@option("--output", required=True, help="the Feather file to write distance samples to")
@option(
    "--threads",
    type=IntRange(1),
    default=1,
    show_default=True,
    help="the number of threads",
)
def main(data_input, seed_input, output, threads):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    X = pd.read_feather(data_input)

    debug(f"Result: {X.shape}")

    # Load seeds.

    info("Loading seeds")

    seeds = [int(x) for x in seed_input]

    debug(f"Result: {len(seeds)} seeds")

    # Reformat data so that left- and right-side data are matched.

    info("Reformatting data")

    X_left = X.loc[X["reference_side"] == "left"]

    X_right = X.loc[X["reference_side"] == "right"]

    X_left = X_left.rename(
        columns={"conditional_probability": "conditional_probability_a"}
    ).set_index(["classification", "reference_root", "co_occurring_root"])[
        ["conditional_probability_a"]
    ]

    X_right = X_right.rename(
        columns={"conditional_probability": "conditional_probability_b"}
    ).set_index(["classification", "reference_root", "co_occurring_root"])[
        ["conditional_probability_b"]
    ]

    X_reformatted = X_left.join(X_right)

    debug(f"Result: {X_reformatted.shape}")

    # Conduct the permutation test.

    info("Conducting permutation tests")

    samples = pd.concat(
        jl.Parallel(n_jobs=threads)(
            jl.delayed(do_permutation_test)(X_reformatted, seed)
            for seed in tqdm.tqdm(seeds)
        )
    )

    # Write output.

    info("Writing output")

    samples.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
