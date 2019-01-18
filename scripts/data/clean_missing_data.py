"""
Ensures extracted variables are within proper limits.

Notably, 8888 and 9999 denote special values that need to be omitted. As no
normal values are this high, we will ignore any values ≥8888.
"""

import click
import feather
import numpy as np
import pandas as pd

from logging import *


def clean_values(x: pd.Series) -> pd.Series:

    return np.where(x >= 8888, np.tile(np.nan, x.size), x)


@click.command()
@click.option(
    '--input', required=True, help='read input data from Feather file INPUT')
@click.option(
    '--output',
    required=True,
    help='output cleaned data to Feather file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading input data')

    data = feather.read_dataframe(input)

    data.info()

    info('\n{}'.format(data.describe()))

    info('Removing blank visits')

    data = data.loc[data['visit_id'].notnull()]

    info('Cleaning missing data')

    data = data.set_index(['subject_id', 'visit_id'])

    data = data.apply(clean_values)

    data = data.reset_index()

    info('\n{}'.format(data.describe()))

    info('Writing output')

    data.info()

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()