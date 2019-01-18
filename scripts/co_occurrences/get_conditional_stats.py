"""
Conducts permutation tests to determine which conditional joint involvements
are observed more than by random chance.
"""

from click import *
from logging import *
from typing import *

import itertools as it
import joblib as jl
import numpy as np
import pandas as pd
import tqdm


def get_seeds(iterations: int, seed: int) -> List[int]:
    """
    Obtains a list of seeds.

    Args:
        iterations: number of iterations
        seed: the initial seed
    """

    seeds = []

    random_state = np.random.RandomState()

    while len(seeds) < iterations:

        random_state.seed(seed)

        seeds += list(random_state.get_state()[1][1:])

        seed = seeds[-1]

    return seeds[:iterations]


def split_data(X: pd.DataFrame, clusters: pd.Series) -> Dict[int, pd.DataFrame]:
    """
    Splits the given data by the given cluster assignments.

    Args:
        x: data
        clusters: cluster assignments
    """

    if clusters is None:

        return {0: X}

    return {k: X.loc[clusters.index[clusters == k]] for k in clusters.unique()}


def _get_co_occurrence(i: str, xi: pd.Series, j: str, xj: pd.Series) -> pd.DataFrame:
    """
    Calculates the conditional joint co-occurrence probability for a given reference
    joint, values for the reference joint, co-occurring joint, and values for the
    co-occurring joint.

    Args:
        i: the reference joint
        xi: values for the reference joint
        j: the co-occurring joint
        xj: values for the co-occurring joint
    """

    frequency = (xi & xj).sum()

    reference_count = xi.sum()

    conditional_probability = (
        frequency / reference_count if reference_count > 0 else np.nan
    )

    return pd.DataFrame(
        {
            "reference_site": [i],
            "co_occurring_site": [j],
            "conditional_probability": [conditional_probability],
        }
    )


def _get_permuted_conditional_probabilities(
    k: int, X: pd.DataFrame, seed: int
) -> pd.DataFrame:
    """
    Obtains conditional probabilities from permuted data for a given cluster with the
    given data frame, and seed.

    k: the cluster number
    X: data to permute
    seed: the seed to initialize the algorithm with
    """

    np.random.seed(seed)

    shuffled_df = X.apply(np.random.permutation)

    shuffled_df.reset_index(drop=True, inplace=True)

    variables = X.columns

    jobs = it.product(variables, variables)

    results = pd.concat(
        _get_co_occurrence(i, shuffled_df[i], j, shuffled_df[j]) for i, j in jobs
    )

    results["classification"] = k

    results["seed"] = seed

    for j in ["reference_site", "co_occurring_site"]:

        results[j] = results[j].astype("category")

    return results


def get_permuted_conditional_probabilities(
    Xs: Dict[int, pd.DataFrame], seeds: pd.Series, threads: int
) -> pd.DataFrame:
    """
    Obtains conditional probabilities from permuted data with the given data
    frames and seeds.

    Args:
        Xs: data split by cluster
        seeds: seeds to initialize the algorithms with
        threads: the number of CPU cores
    """

    n_jobs = len(Xs) * len(seeds)

    jobs = tqdm.tqdm(it.product(Xs.keys(), seeds), total=n_jobs)

    return pd.concat(
        jl.Parallel(n_jobs=threads)(
            jl.delayed(_get_permuted_conditional_probabilities)(k, Xs[k], s)
            for k, s in jobs
        )
    ).reset_index(drop=True)


def _get_p_value(
    k: Tuple[int, str, str],
    conditional_probability: float,
    probability_samples: pd.Series,
) -> pd.DataFrame:
    """
    Calculates, for a conditional probability, the probability that higher conditional
    probabilities will be observed at random.

    Args:
        k: the classification, reference joint, and co-occurring joint
        conditional_probability: the observed conditional probability
        probability_samples: bootstrapped probability samples
    """

    return pd.DataFrame(
        {
            "classification": k[0],
            "reference_site": k[1],
            "co_occurring_site": k[2],
            "p": (probability_samples > conditional_probability).mean(),
        },
        index=[0],
    )


def get_p_values(
    co_occurrences: pd.Series, X_conditionals: pd.DataFrame
) -> pd.DataFrame:
    """
    Obtains P-values for the given co-occurrences and permuted conditional
    probabilities.

    Args:
        co_occurrences: co-occurrences
        X_conditionals: conditional co-occurrences
    """

    info("Calculating P-values")

    g = X_conditionals.groupby(
        ["classification", "reference_site", "co_occurring_site"]
    )

    iterator = tqdm.tqdm(g.groups.items())

    results = pd.concat(
        _get_p_value(
            k, co_occurrences.loc[k], X_conditionals.loc[ix, "conditional_probability"]
        )
        for k, ix in iterator
    ).reset_index(drop=True)

    return results[["classification", "reference_site", "co_occurring_site", "p"]]


def write_output(df, path):
    """
    Writes the given table to the given path.

    :param pd.DataFrame df

    :param str path
    """

    info("Writing output to {}".format(path))

    df.to_csv(path, index=False)


@command()
@option(
    "--data-input",
    required=True,
    help="the CSV file to read joint involvement data from",
)
@option(
    "--co-occurrence-input",
    required=True,
    help="the Feather file to read co-occurrence information from Feather file",
)
@option("--output", required=True, help="the CSV file to write P-values to")
@option("--cluster-input", help="the CSV file to read cluster assignments from")
@option(
    "--iterations",
    type=IntRange(1),
    default=2000,
    show_default=True,
    help="the number of iterations",
)
@option(
    "--threads",
    type=IntRange(1),
    default=1,
    show_default=True,
    help="the number of CPU threads",
)
@option(
    "--seed",
    type=int,
    default=53730459,
    help="the seed to initialize the analysis with",
)
def main(
    data_input, co_occurrence_input, output, cluster_input, iterations, threads, seed
):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading data")

    data = pd.read_csv(data_input, index_col=0)

    debug(f"Result: {data.shape}")

    info("Loading co-occurrences")

    co_occurrences = pd.read_feather(co_occurrence_input).set_index(
        ["classification", "reference_site", "co_occurring_site"]
    )["conditional_probability"]

    debug(f"Result: {co_occurrences.shape}")

    clusters = None

    if cluster_input:

        info("Loading cluster assignments")

        clusters = pd.read_csv(cluster_input, index_col=0, squeeze=True)

        debug(f"Result: {clusters.shape}")

    # Split data by cluster.

    info("Splitting data by cluster")

    splitted_data = split_data(data, clusters)

    # Get seeds.

    info("Generating seeds")

    seeds = get_seeds(iterations, seed)

    # Obtain conditional probabilities from permutations.

    info("Obtaining conditional probabilities from permutations")

    permuted_conditionals = get_permuted_conditional_probabilities(
        splitted_data, seeds, threads
    )

    debug(f"Result: {permuted_conditionals.shape}")

    # Get P-values.

    info("Calculating P-values")

    p_values = get_p_values(co_occurrences, permuted_conditionals)

    # Write output.

    info("Writing output")

    p_values.to_csv(output, index=False)


if __name__ == "__main__":
    main()
