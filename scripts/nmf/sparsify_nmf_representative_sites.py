"""
Sparsifies the given NMF model based on representative sites or factors.
"""

import click
import functools
import numpy as np
import pandas as pd

from logging import *
from sklearn.decomposition import NMF
from sklearn.externals import joblib as sklearn_joblib


def clean_basis_vector(x: pd.Series, coefficient: float) -> np.ndarray:

    return np.where(x >= np.max(x) * coefficient, x, np.zeros(x.size))


@click.command()
@click.option(
    '--model-input',
    required=True,
    help='read the model from Pickle file MODEL_INPUT')
@click.option(
    '--data-input',
    required=True,
    help='read input data from CSV file DATA_INPUT')
@click.option(
    '--model-output',
    required=True,
    help='output the resulting model to Pickle file MODEL_OUTPUT')
@click.option(
    '--basis-output',
    required=True,
    help='output the resulting basis matrix to CSV file BASIS_OUTPUT')
@click.option(
    '--score-output',
    required=True,
    help='output the resulting scores to CSV file SCORE_OUTPUT')
@click.option(
    '--coefficient',
    type=float,
    default=1.,
    help=('for each site, zero basis matrix entries that are COEFFICIENT '
          'times the maximum (default 1)'))
def main(model_input, data_input, model_output, basis_output, score_output,
         coefficient):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(model_output), mode='w')
        ])

    info('Reading input data')

    data = pd.read_csv(data_input, index_col=0)

    data.info()

    info('Loading model')

    model = sklearn_joblib.load(model_input)

    info('Sparsifying basis')

    original_basis = pd.DataFrame(
        model.components_.T,
        index=pd.Series(
            data.columns, name='variable'),
        columns=np.arange(model.n_components) + 1)

    new_basis = original_basis.copy()
    for j, values in new_basis.iteritems():
        new_basis.loc[:, j] = clean_basis_vector(values, coefficient=coefficient)

    info('Rescaling factors')

    original_norms = ((original_basis**2).sum())**0.5

    new_norms = ((new_basis**2).sum())**0.5

    scales = original_norms / new_norms

    info('Scaling factors by following factors:\n{}'.format(scales))

    new_basis *= scales

    info('Modifying model')

    model.components_ = new_basis.values.T

    info('Getting scores')

    scores = pd.DataFrame(
        model.transform(data), index=data.index, columns=new_basis.columns)

    info('Writing model to {}'.format(model_output))

    sklearn_joblib.dump(model, model_output)

    info('Writing basis to {}'.format(basis_output))

    new_basis.to_csv(basis_output)

    info('Writing scores to {}'.format(score_output))

    scores.to_csv(score_output)


if __name__ == '__main__':

    main()