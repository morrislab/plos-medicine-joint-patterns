"""
Reorders factors in a manual fashion.
"""

import numpy as np
import pandas as pd

from click import *
from logging import *
from sklearn.decomposition import NMF
from sklearn.externals import joblib


@command()
@option(
    '--model-input',
    required=True,
    help='the Pickle file to read the model from')
@option(
    '--basis-input',
    required=True,
    help='the CSV file to read the basis matrix from')
@option(
    '--score-input', required=True, help='the CSV file to read scores from')
@option(
    '--model-output',
    required=True,
    help='the Pickle file to write the model to')
@option(
    '--basis-output',
    required=True,
    help='the CSV file to write the basis matrix to')
@option(
    '--score-output', required=True, help='the CSV file to write scores to')
@option(
    '--at-end',
    type=int,
    multiple=True,
    help='the factors to move to the end (multiple permitted)')
def main(model_input, basis_input, score_input, model_output, basis_output,
         score_output, at_end):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(model_output), mode='w')
        ])

    # Load the model.

    info('Loading model')

    model = joblib.load(model_input)

    info('Loading basis matrix')

    basis = pd.read_csv(basis_input, index_col=0)

    info('Result: {}'.format(basis.shape))

    info('Loading scores')

    scores = pd.read_csv(score_input, index_col=0)

    info('Result: {}'.format(scores.shape))

    # Generate a new ordering for the factors.

    info('Reordering factors')

    factor_order = np.arange(model.components_.shape[0], dtype=int) + 1

    if at_end:

        at_end = np.array(at_end, dtype=int)

        factor_order = np.concatenate(
            [np.setdiff1d(factor_order, at_end), at_end])

    model.components_ = model.components_[factor_order - 1]

    basis = basis.iloc[:, factor_order - 1]

    basis.columns = factor_order

    scores = scores.iloc[:, factor_order - 1]

    scores.columns = factor_order

    # Write the output.

    info('Writing output')

    joblib.dump(model, model_output)

    basis.to_csv(basis_output)

    scores.to_csv(score_output)


if __name__ == '__main__':
    main()