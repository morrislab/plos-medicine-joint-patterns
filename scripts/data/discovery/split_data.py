"""
Splits the given data by visit.
"""

import click
import feather

from logging import *
from tqdm import tqdm


@click.command()
@click.option(
    '--input', required=True, help='read input data from Feather file INPUT')
@click.option(
    '--output-prefix',
    required=True,
    help='output extracted data to CSV files starting with OUTPUT_PREFIX')
def main(input, output_prefix):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output_prefix), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = feather.read_dataframe(input)

    data.info()

    info('Splitting data')

    for i in tqdm(data['visit_id'].dropna().astype(int).unique()):

        df = data.loc[data['visit_id'] == i].drop('visit_id', axis=1)

        df.to_csv('{}{:02d}.csv'.format(output_prefix, i), index=False)


if __name__ == '__main__':

    main()