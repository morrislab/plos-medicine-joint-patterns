"""
Counts the number of patients by patient group and localizations.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option('--input', required=True, help='the CSV file to read input data from')
@option('--output', required=True, help='the CSV to write counts to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading data')

    data = pd.read_csv(input)

    info('Calculating counts')

    counts = data.groupby(['classification',
                           'localization'])['subject_id'].count()

    counts.name = 'count'

    info('Writing output')

    counts.to_frame().to_csv(output)


if __name__ == '__main__':
    main()