"""
Filters site involvement data.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the Feather file to load site information from')
@option(
    '--filter-input',
    required=True,
    help='the CSV file to load patient filtering information from')
@option(
    '--output',
    required=True,
    help='the Feather file to output the filtered site information to')
def main(data_input, filter_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading site information')

    df_sites = feather.read_dataframe(data_input).set_index('subject_id')

    info('Result: {}'.format(df_sites.shape))

    info('Loading patient filter')

    df_filter = pd.read_csv(filter_input, index_col='subject_id')

    info('Result: {}'.format(df_filter.shape))

    # Filter the data.

    info('Filtering data')

    df_filtered = df_sites.loc[df_filter['mask']]

    # Write the output.

    info('Writing output')

    feather.write_dataframe(df_filtered.reset_index(), output)


if __name__ == '__main__':
    main()