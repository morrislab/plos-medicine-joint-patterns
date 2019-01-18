"""
Filters core set data to patients of interest.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the Feather file to read core set data from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read patient groups from')
@option('--output', required=True, help='the Feather file to write output to')
def main(data_input, cluster_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(data_input)

    info('Result: {}'.format(data.shape))

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col='subject_id', squeeze=True)

    info('Result: {}'.format(clusters.shape))

    # Filter the data.

    info('Filtering data')

    data = data.loc[data['visit_id'] == 1].drop(
        'visit_id', axis=1).set_index('subject_id')

    data = data.loc[clusters.index]

    # Merge the cluster assignments in.

    info('Merging clusters')

    data['classification'] = clusters

    # Write the output.

    info('Writing output')

    data['classification'] = data['classification'].astype('category')

    feather.write_dataframe(data.reset_index(), output)


if __name__ == '__main__':
    main()
