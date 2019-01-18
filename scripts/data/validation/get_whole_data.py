"""
Obtains whole data from the validation cohort.
"""

import feather

from click import *
from logging import *


@command()
@option(
    '--input', required=True, help='the Feather file to read input data from')
@option('--output', required=True, help='the CSV file to output data to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(input).set_index('subject_id')

    info('Result: {}'.format(data.shape))

    # Filter to patients with at least one joint involved.

    info('Filtering to patients with at least one joint involved')

    data = data.loc[data.sum(axis=1) > 0]

    # Write the output.

    info('Writing output')

    data.to_csv(output)


if __name__ == '__main__':
    main()