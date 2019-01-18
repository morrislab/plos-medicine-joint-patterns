"""
Obtains optimal thresholds for full localization.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option('--input', required=True, help='the CSV file to read stats from')
@option(
    '--output',
    required=True,
    help='the text file to output the optimal threshold to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading stats')

    stats = pd.read_csv(input, index_col='threshold')

    debug(f'Result: {stats.shape}')

    info('Determining optimal threshold')

    upper_bound = stats['mean'].loc[1] + stats['se'].loc[1]

    threshold = stats.query('mean <= @upper_bound')['mean'].index[0]

    info('Writing output')

    with open(output, 'w') as handle:

        handle.write(str(threshold))


if __name__ == '__main__':
    main()