"""
Calculates Q2 between original data and their reconstruction.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to read the input data from')
@option(
    '--reconstruction-input',
    required=True,
    help='the CSV file to read the reconstructions from')
@option(
    '--output', required=True, help='the text file to write the Q2 value to')
def main(data_input, reconstruction_input, output):

    basicConfig(level=DEBUG)

    # Load the data.

    info('Loading data...')

    info('Loading data')

    X = pd.read_csv(data_input, index_col=0)

    debug(f'Result: {X.shape}')

    info('Loading reconstructions')

    X_hat = pd.read_csv(reconstruction_input, index_col=0)

    debug(f'Result: {X_hat.shape}')

    # Calculate Q2.

    info('Calculating Q2')

    q2 = 1 - ((X - X_hat)**2).sum().sum() / (X**2).sum().sum()

    # Write the output.

    info('Writing output')

    with open(output, 'w') as h:

        h.write(str(q2))


if __name__ == '__main__':
    main()