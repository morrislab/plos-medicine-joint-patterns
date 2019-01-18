"""
Generates cluster assignments from localization data.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read clusters and localizations from')
@option(
    '--output',
    required=True,
    help='the CSV file to write localized clusters to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading clusters and localizations')

    df = pd.read_csv(input)

    info('Result: {}'.format(df.shape))

    df['classification'] += '_' + df['localization']

    df.drop('localization', axis=1, inplace=True)

    info('Writing output')

    df.to_csv(output, index=False)


if __name__ == '__main__':
    main()