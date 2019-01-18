"""
Casts medication statuses by type.
"""

import feather

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to load medication statuses from')
@option(
    '--output', required=True, help='the CSV file to output casted data to')
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

    # Filter to unique entries.

    info('Filtering to unique entries')

    data = data[['subject_id', 'type']].drop_duplicates()

    # Cast medication statuses.

    info('Casting medication statuses')

    data['value'] = 1

    casted = data.pivot_table(
        index='subject_id',
        columns='type',
        values='value',
        aggfunc='max',
        fill_value=0)

    # Write the output.

    info('Writing output')

    casted.to_csv(output)


if __name__ == '__main__':
    main()