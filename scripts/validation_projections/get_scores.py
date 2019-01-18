"""
Calculates factor scores from input data.
"""

import numpy as np
import pandas as pd
from sklearn.externals import joblib

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to read classifications from')
@option(
    '--model-input',
    required=True,
    help='the Pickle file to read the model from')
@option('--output', required=True, help='the CSV file to write scores to')
def main(data_input: str, model_input: str, output: str):

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

    info('Loading model')

    model = joblib.load(model_input)

    # XXX

    model.beta_loss = 'frobenius'

    # Project the data onto the factors.

    info('Calculating scores')

    scores = pd.DataFrame(
        model.transform(data),
        index=data.index,
        columns=(np.arange(model.n_components) + 1).astype('str'))

    # Write the output.

    info('Writing output')

    scores.to_csv(output)


if __name__ == '__main__':
    main()
