"""
Calculates involvement frequencies for each site in each patient group.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option('--data-input', required=True, help='the CSV file to read data from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read clusters from')
@option('--output', required=True, help='the CSV file to write results to')
def main(data_input, cluster_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input)

    info('Result: {}'.format(data.shape))

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0)

    info('Result: {}'.format(clusters.shape))

    # Melt the data.

    info('Melting data')

    melted_data = data.melt(
        id_vars='subject_id', var_name='site').set_index('subject_id')

    # Join clusters to the data.

    info('Joining data')

    joined_data = melted_data.join(clusters, how='inner')

    # Calculate per-patient group frequencies.

    info('Calculating frequencies by patient group')

    frequencies = joined_data.groupby(
        ['classification', 'site'])['value'].mean()

    frequencies.name = 'frequency'

    frequencies = frequencies.reset_index()

    # Write the output.

    info('Writing output')

    frequencies.to_csv(output, index=False)


if __name__ == '__main__':
    main()
