"""
Generates unified classifications.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read classifications and localizations from')
@option(
    '--output',
    required=True,
    help='the CSV file to write unified classifications to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the assignments.

    info('Loading assignments')

    assignments = pd.read_csv(input)

    info('Result: {}'.format(assignments.shape))

    # Generate unified assignments.

    info('Generating unified assignments')

    assignments['classification'] = assignments[
        'classification'] + '_' + assignments['localization']

    assignments.drop(['localization', 'threshold'], axis=1, inplace=True)

    # Write the output.

    info('Writing output')

    assignments.to_csv(output, index=False)


if __name__ == '__main__':
    main()