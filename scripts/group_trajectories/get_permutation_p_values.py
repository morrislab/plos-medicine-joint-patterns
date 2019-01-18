"""
Obtains P-values from the permutation test.
"""

import feather
import itertools as it
import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *


def calculate_probability(
    probabilities: pd.DataFrame, samples: pd.DataFrame, source: str, target: str
) -> pd.DataFrame:
    """
    Calculates the probability that the sampled probabilities are at least the
    observed probabilities or are unobserved.

    Args:
        probabilities: The observed probabilities.
        samples: The sampled probabilities.
        source: The source cluster.
        target: The target cluster.

    Returns:
        The probability.
    """

    probabilities_filtered = probabilities.query(
        "source == @source and target == @target"
    )

    samples_filtered = samples.query("source == @source and target == @target")

    # XXX Fix for pandas 0.23.x bug.

    # total_iterations = samples["seed"].unique().size
    total_iterations = len(set(samples["seed"]))

    base_probability = (
        probabilities_filtered["probability"].iloc[0]
        if probabilities_filtered.shape[0] > 0
        else 0.
    )

    # num_missing_iterations = total_iterations - samples_filtered["seed"].unique().size
    num_missing_iterations = total_iterations - len(set(samples_filtered["seed"]))

    num_geq = (samples_filtered["probability"] > base_probability).sum()

    p = (num_missing_iterations + num_geq) / total_iterations

    return pd.DataFrame(
        {
            "source": source,
            "target": target,
            "n": total_iterations,
            "n_missing": num_missing_iterations,
            "n_above": num_geq,
            "p": p,
        },
        index=[0],
    )


@command()
@option(
    "--probability-input",
    required=True,
    help="the CSV file to read base probabilities from",
)
@option("--sample-input", required=True, help="the Feather file to read samples from")
@option("--output", required=True, help="the CSV file to write P-values to")
def main(probability_input, sample_input, output):

    basicConfig(level=DEBUG)

    # Load the base probabilities.

    info("Loading base probabilities")

    X_probabilities = pd.read_csv(
        probability_input, dtype={"source": "category", "target": "category"}
    )

    debug(f"Result: {X_probabilities.shape}")

    # Load the samples.

    info("Loading samples")

    samples = pd.read_feather(sample_input)

    # For each combination of sources and targets, calculate the probability
    # that the sampled probability is higher than the observed probability.

    info("Calculating P(sampled > observed)")

    source_unique = X_probabilities["source"].unique()

    target_unique = X_probabilities["target"].unique()

    n_pairs = source_unique.shape[0] * target_unique.shape[0]

    iterator = tqdm.tqdm(
        it.product(source_unique, target_unique), total=n_pairs, mininterval=1
    )

    probs = pd.concat(
        calculate_probability(X_probabilities, samples, source, target)
        for source, target in iterator
    )

    # Write the output.

    info("Writing output")

    probs.to_csv(output, index=False)


if __name__ == "__main__":
    main()
