"""
Obtains optimal thresholds for partial localization.

This threshold is determined by where the most negative slope occurs.
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

    stats = pd.read_csv(input)

    stats.set_index('threshold', drop=False, inplace=True)

    debug(f'Result: {stats.shape}')

    info('Calculating slopes')

    rises = stats['mean'].shift(-1) - stats['mean'].shift(1)

    runs = stats['threshold'].shift(-1) - stats['threshold'].shift(1)

    slopes = rises / runs

    info('Determining optimal threshold')

    threshold = slopes.argmin()

    info('Writing output')

    with open(output, 'w') as handle:

        handle.write(str(threshold))


if __name__ == '__main__':
    main()