"""
Reconstructs data for a single level of NMF.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    '--basis-input',
    required=True,
    help='the CSV file to read the basis matrix from')
@option(
    '--coefficient-input',
    required=True,
    help='the CSV file to read the coefficient matrix from')
@option('--output', required=True, help='the CSV file to write the output to')
def main(basis_input, coefficient_input, output):

    basicConfig(level=INFO)

    # Load the data.

    info('Loading inputs...')

    info('Loading basis matrix')

    basis = pd.read_csv(basis_input, index_col=0)

    debug(f'Result: {basis.shape}')

    info('Loading coefficient matrix')

    coefficients = pd.read_csv(coefficient_input, index_col=0)

    debug(f'Result: {coefficients.shape}')

    # Reconstruct the data.

    info('Generating reconstruction')

    X_hat = coefficients.dot(basis.T)

    # Write the output.

    info('Writing output')

    X_hat.to_csv(output)


if __name__ == '__main__':
    main()