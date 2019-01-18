"""
Selects useful data.
"""

import click
import pandas as pd

from logging import *


@click.command()
@click.option(
    '--input', required=True, help='read input data from CSV file INPUT')
@click.option('--output', required=True, help='output selected data to OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = pd.read_csv(input)

    data.info()

    n_unique = pd.Series(
        {j: data[j].dropna().unique().size
         for j in data.columns})

    columns_to_drop = sorted(n_unique.loc[n_unique < 2].index)

    info('Dropping columns: {!r}'.format(columns_to_drop))

    data.drop(columns_to_drop, axis=1, inplace=True)

    info('Writing output')

    data.info()

    data.to_csv(output, index=False)


if __name__ == '__main__':

    main()