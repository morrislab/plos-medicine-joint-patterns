"""
Filters joint involvement data in the validation cohort.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--sites-input',
    required=True,
    metavar='SITES-INPUT',
    help='load site involvements from Feather file SITES-INPUT')
@option(
    '--filter-input',
    required=True,
    metavar='FILTER-INPUT',
    help='load filters from Feather file FILTER-INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output filtered data to CSV file OUTPUT')
def main(sites_input, filter_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading site data')

    data = feather.read_dataframe(sites_input).set_index('subject_id')

    data.info()

    info('Loading filters')

    filters = pd.read_csv(filter_input, index_col=0)

    filters.info()

    # Apply the filters.

    info('Applying filters')

    data = data.loc[filters['mask'] == True]

    # Write the output.

    info('Writing output')

    data.info()

    data.to_csv(output)


if __name__ == '__main__':
    main()