"""
Calculates representative sites for each factor.
"""

import pandas as pd
import string

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read the basis matrix from')
@option(
    '--output',
    required=True,
    help='the CSV file to output representative factors to')
@option(
    '--letters/--no-letters',
    default=False,
    help='translate factors to letters')
def main(input, output, letters):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = pd.read_csv(input)

    data.info()

    info('Identifying representative sites')

    representative_factors = pd.melt(
        data, id_vars=['variable'], var_name='factor')

    representative_factors = representative_factors.loc[representative_factors[
        'value'] > 0].drop(
            'value', axis=1).rename(columns={'variable': 'site'})

    if letters:

        info('Converting factors to letters')

        representative_factors['factor'] = (
            representative_factors['factor'].astype(int) - 1
        ).map(string.ascii_uppercase.__getitem__)

    else:

        info('Formatting factor numbers')

        representative_factors['factor'] = (
            representative_factors['factor'].astype(int)).map('{:02d}'.format)

    info('Writing output')

    representative_factors.info()

    representative_factors.to_csv(output, index=False)


if __name__ == '__main__':
    main()