"""
Extracts medication information from the validation cohort.
"""

import collections
import feather
import pandas as pd

from click import *
from logging import *

COLUMNS = collections.OrderedDict(
    [('ID', 'subject_id'), ('TIMEFRAME', 'visit_id'),
     ('IAS', 'medication_joint_injections'), ('NSAID', 'medication_nsaids'),
     ('DMARD', 'medication_dmards'), ('BIOLOGIC', 'medication_biologics'),
     ('CORTICOSTEROIDS', 'medication_steroids')])


@command()
@option(
    '--input',
    required=True,
    metavar='INPUT',
    help='load input data from Excel file INPUT')
@option(
    '--visit',
    type=int,
    required=True,
    metavar='VISIT',
    help='extract data from visit VISIT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output extracted data to Feather file OUTPUT')
def main(input, visit, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading and selecting data')

    data = pd.read_excel(input)

    data.info()

    df = data[list(COLUMNS.keys())].copy()

    df.rename(columns=COLUMNS, inplace=True)

    # Filter the data.

    info('Filtering data')

    df = df.query('visit_id == @visit').copy()

    df.drop('visit_id', axis=1, inplace=True)

    # Output the resulting data.

    info('Writing data')

    df.info()

    feather.write_dataframe(df, output)


if __name__ == '__main__':
    main()