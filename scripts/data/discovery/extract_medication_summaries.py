"""
Extracts medication information.
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
@click.option(
    '--grace-period',
    type=int,
    default=0,
    help=('use GRACE_PERIOD as the grace period before visits for being on a '
          'medication (in days)'))
def main(input, output, grace_period):

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
        'SUBJECT_ID', 'VISIT_ID', 'NSAID_STATUS', 'DMARD_STATUS',
        'STEROID_SYST_1_STATUS', 'IV_GG_STATUS', 'BIO_STATUS'
    ]]

    data.columns = [
        'subject_id', 'visit_id', 'nsaid_status', 'dmard_status',
        'steroid_status', 'ivig_status', 'biologic_status'
    ]

    for j in [
            'nsaid_status', 'dmard_status', 'steroid_status', 'ivig_status',
            'biologic_status'
    ]:

        data[j] = data[j].astype('category')

    data.info()

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()