"""
Extracts information about joint injections.
"""

import click
import feather
import pandas as pd

from logging import *


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

    data = data[[
        'SUBJECT_ID', 'VISIT_ID', 'INJECTION STATUS', 'DAYS_1', 'DAYS_2',
        'DAYS_3'
    ]]

    days_columns = ['days_1', 'days_2', 'days_3']

    data.columns = ['subject_id', 'visit_id', 'injection_status'
                    ] + days_columns

    data['injection_status'] = data['injection_status'].astype('category')

    info('Determining most distant joint injection')

    data['days_max'] = data[days_columns].apply(pd.Series.max, axis=1)

    data.drop(days_columns, axis=1, inplace=True)

    data.info()

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()