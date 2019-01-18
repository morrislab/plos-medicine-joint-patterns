"""
Aligns data so that their column names are in the same order as the reference
data.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to read classifications from')
@option(
    '--reference-input',
    required=True,
    help='the CSV file to read reference data from')
@option(
    '--output',
    required=True,
    help='the CSV file to write the transformed data to')
def main(data_input: str, reference_input: str, output: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input, index_col=0)

    info('Result: {}'.format(data.shape))

    info('Loading reference data')

    reference_data = pd.read_csv(reference_input, index_col=0)

    info('Result: {}'.format(reference_data.shape))

    # Conduct a sanity check to ensure that all fields are properly
    # represented.

    info('Checking fields')

    bad_data_fields = data.columns.difference(reference_data.columns)

    if bad_data_fields.shape[0] > 0:

        raise KeyError('data contains extra columns: {!r}'.format(
            sorted(bad_data_fields.tolist())))

    bad_reference_fields = reference_data.columns.difference(data.columns)

    if bad_reference_fields.shape[0] > 0:

        warning('Reference data contains extra columns: {!r}'.format(
            sorted(bad_reference_fields.tolist())))

        for j in bad_reference_fields:

            data[j] = 0

    # Align the data.

    info('Aligning data')

    aligned_data = data[reference_data.columns]

    # Write the output.

    info('Writing output')

    aligned_data.to_csv(output)


if __name__ == '__main__':
    main()
