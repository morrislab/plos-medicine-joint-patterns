"""
Bootstraps Euclidean distances in site frequencies between the validation and
discovery cohorts.
"""

import feather
import functools as ft
import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *
from sklearn.utils import resample


def bootstrap_distances_cluster(df: pd.DataFrame,
                                discovery_frequencies: pd.DataFrame,
                                seed: int) -> float:
    """
    Calculates a bootstrapped Euclidean distance in site frequencies for a
    single cluster.

    Args:
        df: the data for the cluster.
        discovery_frequencies: a table of discovery cohort site frequencies per
            patient group.
        seed: the seed to initialize the random number generator with.
    """

    cluster = df['classification'].unique()[0]

    discovery_frequencies_cluster = discovery_frequencies.loc[cluster][
        'frequency']

    resampled_data = resample(
        df.drop('classification', axis=1), random_state=seed)

    validation_frequencies = resampled_data.mean()

    return np.sqrt(((validation_frequencies - discovery_frequencies_cluster)
                    **2).sum())


def bootstrap_distances(df: pd.DataFrame, discovery_frequencies: pd.DataFrame,
                        seed: int) -> pd.DataFrame:
    """
    Generates bootstrapped distances.

    Args:
        df: a table of site involvements and cluster assignments.
        discovery_frequencies: a table of discovery cohort site frequencies per
            patient group.
        seed: the seed to initialize the random number generator with.
    """

    samples = df.groupby('classification').apply(
        ft.partial(
            bootstrap_distances_cluster,
            discovery_frequencies=discovery_frequencies,
            seed=seed))

    samples.name = 'distance'

    samples = samples.reset_index()

    samples['seed'] = seed

    return samples


@command()
@option(
    '--data-input', required=True, help='the CSV file to read input data from')
@option(
    '--discovery-frequency-input',
    required=True,
    help='the CSV file to read discovery frequencies from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--seeds',
    required=True,
    type=File('rU'),
    help='the text file to read seeds from')
@option(
    '--output',
    required=True,
    help='the Feather file to write sample distances to')
def main(data_input: str, discovery_frequency_input: str, cluster_input: str,
         seeds, output: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading site involvement data')

    data = pd.read_csv(data_input, index_col=0)

    info('Result: {}'.format(data.shape))

    info('Loading discovery frequency data')

    discovery_frequencies = pd.read_csv(
        discovery_frequency_input, index_col=['classification', 'site'])

    info('Result: {}'.format(discovery_frequencies.shape))

    info('Loading cluster assignments')

    clusters = pd.read_csv(cluster_input, index_col=0)

    info('Result: {}'.format(clusters.shape))

    info('Loading seeds')

    seeds = [int(x) for x in seeds]

    info('Result: {} seeds'.format(len(seeds)))

    # Merge cluster assignments with the site involvement data.

    info('Merging data')

    merged_data = data.join(clusters)

    # Conduct the bootstrap.

    info('Calculating bootstrapped distances')

    bootstrapped_distances = (bootstrap_distances(
        df=merged_data, discovery_frequencies=discovery_frequencies, seed=seed)
                              for seed in tqdm.tqdm(seeds))

    bootstrapped_distances = pd.concat(bootstrapped_distances)

    # Write the output.

    info('Writing output')

    bootstrapped_distances['classification'] = bootstrapped_distances[
        'classification'].astype('category')

    feather.write_dataframe(bootstrapped_distances, output)


if __name__ == '__main__':
    main()
