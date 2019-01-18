"""
Cleans the validation data, renaming columns and removing sites involved in no
one.
"""

import click
import pandas as pd

from logging import *


@click.command()
@click.option(
    '--input',
    required=True,
    help='read input data from CSV file INPUT')
@click.option(
    '--output',
    required=True,
    help='output cleaned data to CSV file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading input data')

    data = pd.read_csv(input, index_col=0)

    data.info()

    info('Removing sites involved in no one')

    sums = data.sum()

    data = data.loc[:, sums > 0]

    info('Renaming columns')

    new_names = data.columns.str.replace(r'Left$', '_left')

    new_names = new_names.str.replace(r'Right$', '_right')

    new_names = new_names.str.replace('CervicalSpine', 'cervical_spine')

    new_names = new_names.str.replace('ToeIP', 'toe_ip')

    new_names = new_names.str.lower()

    data.columns = new_names

    data.index.name = 'subject_id'

    info('Writing output')

    data.info()

    data.to_csv(output)


if __name__ == '__main__':

    main()