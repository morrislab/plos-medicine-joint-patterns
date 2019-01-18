"""
Enumerates localization classifications.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input', required=True, help='the CSV file to read localizations from')
@option('--output', required=True, help='the CSV file to write counts to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading assignments')

    assignments = pd.read_csv(input)

    info('Result: {}'.format(assignments.shape))

    # Enumerate assignments.

    info('Enumerating assignments')

    counts = assignments.groupby(
        ['classification', 'localization', 'threshold'])['subject_id'].count()

    counts.name = 'count'

    # Write the output.

    info('Writing output')

    counts.to_frame().to_csv(output)


if __name__ == '__main__':
    main()