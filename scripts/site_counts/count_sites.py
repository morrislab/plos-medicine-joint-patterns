"""
Counts the number of sites involved per patient.
"""

import feather
import os.path
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV or Feather file to read site involvements from')
@option('--output', required=True, help='the CSV file to write site counts to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(input).set_index(
        'subject_id') if os.path.splitext(input)[-1].lower(
        ) == '.feather' else pd.read_csv(
            input, index_col=0)

    info('Result: {}'.format(data.shape))

    # Calculate counts.

    info('Calculating counts')

    counts = data.sum(axis=1)

    counts.name = 'count'

    # Write the counts.

    info('Writing counts')

    counts.to_frame().to_csv(output)


if __name__ == '__main__':
    main()
