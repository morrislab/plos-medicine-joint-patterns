"""
Extracts enthesitis information.
"""

import click
import feather
import numpy as np
import pandas as pd
import re

from logging import *


def reformat_name(x: str) -> str:
    """
    Reformats the given column name to lowercase with underscores.

    Args:
        x: the name to convert

    Returns:
        The converted name.
    """

    y = re.sub(r'_+', '_', x.lower())

    y = y.replace('tronchanter', 'trochanter')

    return y


@click.command()
@click.option(
    '--input', required=True, help='read input data from XLS file INPUT')
@click.option(
    '--output',
    required=True,
    help='output extracted data to Feather file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = pd.read_excel(input)

    info('Selecting data')

    data.drop(
        ['CENTRE', 'VISIT_DATE', 'ENTHESITIS', 'NUM_ENTH_SITES'],
        axis=1,
        inplace=True)

    info('Reformatting column names')

    data.columns = [reformat_name(x) for x in data.columns]

    info('Reconciling data')

    enthesitis_columns = data.columns.difference(['subject_id', 'visit_id'])

    for j in enthesitis_columns:

        data[j] = np.where(data[j] > 1., 1., data[j])

    info('Filling missing values as 0')

    data.fillna(0., inplace=True)

    info('Coercing joints to integers')

    for j in enthesitis_columns:

        data[j] = data[j].astype(int)

    info('Writing output')

    data.info()

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()