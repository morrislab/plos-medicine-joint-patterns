"""
Fills missing enthesitis statuses.
"""

import feather

from click import *
from logging import *


@command()
@option('--input', required=True, help='the Feather file to read data from')
@option('--output', required=True, help='the Feather file to write data to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(input)

    info('Result: {}'.format(data.shape))

    # Fill in missing values.

    info('Filling missing values')

    data.loc[:, 'enthesitis'].fillna('N', inplace=True)

    # Write the output.

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':
    main()
