"""
Calculates bootstrapped P-values for distances between site frequencies in the
validation and discovery cohorts.
"""

import feather
import pandas as pd

from click import *
from logging import *


def get_stats(observed: float, cluster: str,
              samples: pd.Series) -> pd.DataFrame:
    """
    Calculates statistics for a single cluster.

    Args:
        observed: the observed distance.
        cluster: the cluster assignment.
        samples: sampled distances.
    """

    n_lower = (samples < observed).sum()

    total = samples.shape[0]

    return pd.DataFrame(
        {
            'classification': cluster,
            'n_lower': n_lower,
            'total': total,
            'p': n_lower / total
        },
        index=[0])


@command()
@option(
    '--observed-input',
    required=True,
    help='the CSV file to read observed distances from')
@option(
    '--sample-input',
    required=True,
    help='the Feather file to read bootstrapped samples from')
@option(
    '--output',
    required=True,
    help='the CSV file to write the transformed data to')
def main(observed_input: str, sample_input: str, output: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading base comparisons')

    observed = pd.read_csv(observed_input, index_col=0, squeeze=True)

    info('Result: {}'.format(observed.shape))

    info('Loading samples')

    samples = feather.read_dataframe(sample_input)

    info('Result: {}'.format(samples.shape))

    # For each cluster, calculate the proportion of samples that are lower than
    # the observed distance.

    info('Calculating statistics')

    samples.drop('seed', axis=1, inplace=True)

    samples.set_index('classification', inplace=True)

    samples = samples.squeeze()

    stats = pd.concat(
        get_stats(v, k, samples[k])
        for k, v in observed.iteritems()).set_index('classification')

    # Write the output.

    info('Writing output')

    stats.to_excel(output)


if __name__ == '__main__':
    main()
