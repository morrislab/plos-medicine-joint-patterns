"""
Unscales reconstructions.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    '--data-input', required=True, help='the CSV file to read input data from')
@option(
    '--scaling-parameter-input',
    required=True,
    help='the CSV file to read scaling parameters from')
@option('--output', required=True, help='the CSV file to write the output to')
def main(data_input, scaling_parameter_input, output):

    basicConfig(level=INFO)

    # Load the data.

    info('Loading inputs...')

    info('Loading data')

    X = pd.read_csv(data_input, index_col=0)

    debug(f'Result: {X.shape}')

    info('Loading scaling parameters')

    scaling_parameters = pd.read_csv(scaling_parameter_input, index_col=0)

    scaling_parameters.index = scaling_parameters.index.astype(str)

    debug(f'Result: {scaling_parameters.shape}')

    # Scale the reconstruction.

    info('Unscaling data')

    X = (X / scaling_parameters['scale']) - scaling_parameters['shift']

    # Write the output.

    info('Writing output')

    X.to_csv(output)


if __name__ == '__main__':
    main()