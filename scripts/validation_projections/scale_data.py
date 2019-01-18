"""
Scales input data given reference parameters.
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
    '--parameter-input',
    required=True,
    help='the CSV file to read parameters from')
@option(
    '--output',
    required=True,
    help='the CSV file to write the transformed data to')
def main(data_input: str, parameter_input: str, output: str):

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

    info('Loading parameters')

    parameters = pd.read_csv(parameter_input, index_col=0)

    parameters.index = parameters.index.astype('str')

    # Conduct a sanity check to ensure that all fields are properly
    # represented.

    info('Checking fields')

    bad_data_fields = data.columns.difference(parameters.index)

    if bad_data_fields.shape[0] > 0:

        raise KeyError('data contains extra columns: {!r}'.format(
            sorted(bad_data_fields.tolist())))

    # Apply the transformations.

    info('Applying transformations')

    data = (data + parameters['shift']) * parameters['scale']

    # Write the output.

    info('Writing output')

    data.to_csv(output)


if __name__ == '__main__':
    main()
