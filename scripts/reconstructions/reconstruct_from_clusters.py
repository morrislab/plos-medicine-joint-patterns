"""
For each patient, calculates their reconstruction based on cluster centroids.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    '--data-input', required=True, help='the CSV file to read input data from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--output',
    required=True,
    help='the CSV file to write the reconstructions to')
def main(data_input, cluster_input, output):

    basicConfig(level=DEBUG)

    # Load the data.

    info('Loading data...')

    info('Loading data')

    X = pd.read_csv(data_input, index_col=0)

    debug(f'Result: {X.shape}')

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0)

    debug(f'Result: {clusters.shape}')

    # Calculate centroids.

    info('Calculating centroids')

    centroids = clusters.join(X).groupby('classification').mean()

    # Generate reconstructions.

    info('Generating reconstructions')

    reconstructions = clusters.reset_index().set_index('classification').join(
        centroids).reset_index().set_index('subject_id').drop(
            'classification', axis=1)

    # Write the output.

    info('Writing output')

    reconstructions.to_csv(output)


if __name__ == '__main__':
    main()