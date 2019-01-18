"""
Desensitizes NMF loadings.
"""

import argparse
import feather
import functools
import logging
import numpy as np
import pandas as pd

from sklearn.decomposition import NMF
from sklearn.externals import joblib as sklearn_joblib


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--model-input',
        required=True,
        metavar='MODEL-INPUT',
        help='read the base model from Pickle file %(metavar)s')

    parser.add_argument(
        '--data-input',
        type=argparse.FileType('rU'),
        required=True,
        metavar='DATA-INPUT',
        help='read input data from CSV file %(metavar)s')

    parser.add_argument(
        '--bootstrapped-sample-input',
        required=True,
        metavar='BOOTSTRAPPED-SAMPLE-INPUT',
        help=('read bootstrapped basis matrix samples from Feather file '
              '%(metavar)s'))

    parser.add_argument(
        '--iterations',
        type=int,
        default=2000,
        help=('run the analysis with %(metavar)s bootstraps (default: '
              '%(default)s)'))

    parser.add_argument(
        '--model-output',
        required=True,
        metavar='MODEL-OUTPUT',
        help='output the model to Pickle file %(metavar)s')

    parser.add_argument(
        '--basis-output',
        required=True,
        metavar='BASIS-OUTPUT',
        help='output the model to CSV file %(metavar)s')

    parser.add_argument(
        '--score-output',
        required=True,
        metavar='SCORE-OUTPUT',
        help='output the model to CSV file %(metavar)s')

    parser.add_argument(
        '--lower-quantile-threshold',
        type=float,
        metavar='LOWER-THRESHOLD',
        default=0.25,
        help=('use %(metavar)s as the lower quantile threshold; the '
              'calculated threshold per factor will be the %(metavar)sth '
              'percentile of the highest median basis matrix entry (default '
              '%(default)s)'))

    parser.add_argument(
        '--upper-quantile',
        type=float,
        metavar='UPPER',
        default=0.75,
        help=('use %(metavar)s as the quantile threshold to determine whether '
              'a variable on a factor has crossed the lower quantile '
              'threshold (default %(default)s)'))

    parser.add_argument(
        '--log',
        metavar='LOG',
        help='write logging information to %(metavar)s')

    return parser.parse_args()


def configure_logging(log=None):
    """
    Configures logging.

    :param str log
    """

    if log:

        logging.basicConfig(
            level=logging.DEBUG,
            filename=log,
            filemode='w',
            format='%(asctime)s %(levelname)-8s %(message)s')

        console = logging.StreamHandler()

        console.setLevel(logging.INFO)

        console.setFormatter(logging.Formatter('%(message)s'))

        logging.getLogger().addHandler(console)

    else:

        logging.basicConfig(level=logging.INFO, format='%(message)s')


def load_data(model_path, data_handle, bootstrap_sample_path):
    """
    Loads a model, input data, and bootstrapped basis matrix samples from the
    given paths and handles.

    :param str model_path

    :param io.file data_handle

    :param str bootstrap_sample_path

    :rtype: Tuple[NMF, pd.DataFrame, pd.DataFrame]
    """

    logging.info('Loading model')

    model = sklearn_joblib.load(model_path)

    logging.info('Loading data')

    result = pd.read_csv(data_handle, index_col=0)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    logging.info('Loading bootstrapped basis matrix samples')

    samples = feather.read_dataframe(bootstrap_sample_path)

    logging.info('Loaded a table with shape {}'.format(samples.shape))

    return model, result, samples


def sparsify_model(model, samples, variables, lower_quantile_threshold,
                   upper_quantile):
    """
    Sparsifies the given model using the given bootstrapped basis matrix
    samples.

    :param NMF model

    :param pd.DataFrame samples

    :param pd.Index[str] variables

    :param float lower_quantile_threshold

    :param float upper_quantile

    :rtype: NMF
    """

    logging.info('Sparsifying model')

    # Calculate statistics.

    statistics = samples.groupby(['factor', 'variable'])['loading'].agg({
        'median': pd.Series.median,
        'lower': functools.partial(
            pd.Series.quantile, q=lower_quantile_threshold),
        'upper': functools.partial(
            pd.Series.quantile, q=upper_quantile)
    })

    # For each factor, determine the variable with the maximum median basis.

    max_basis_variables = statistics.reset_index('factor').groupby('factor')[
        'median'].apply(pd.Series.argmax)

    max_basis_variables.name = 'variable'

    # Set the thresholds for retaining other variables on factors.

    threshold_ix = pd.MultiIndex.from_arrays(
        [max_basis_variables.index, max_basis_variables])

    thresholds = statistics.loc[threshold_ix].reset_index()['lower']

    logging.info('Applying thresholds:')

    for i, threshold in enumerate(thresholds):

        logging.info('  - Factor {}: {}'.format(i + 1, threshold))

    # Prior to modification, calculate the L2 norm of all factors so that we
    # can retain scaling afterwards.

    variable_map = pd.Series(np.arange(len(variables)), index=variables)

    original_l2_norms = np.sqrt(np.sum(model.components_**2, axis=1))

    for j in range(model.n_components):

        # Which variables to modify?

        variables_to_modify = statistics.loc[j + 1]

        variables_to_modify = variables_to_modify.loc[variables_to_modify[
            'upper'] < thresholds.loc[j]]

        logging.info('Factor {}: keeping following variables:'.format(j + 1))

        for k in sorted(variables.difference(variables_to_modify.index)):

            logging.info('  - {}'.format(k))

        if variables_to_modify.shape[0] > 0:

            for v in variables_to_modify.index:

                model.components_[j, variable_map[v]] = 0.

    # Rescale the factors.

    new_l2_norms = np.sqrt(np.sum(model.components_**2, axis=1))

    ratios = original_l2_norms / new_l2_norms

    logging.info('Rescaling factors by following multipliers:')

    for j, ratio in enumerate(ratios):

        logging.info('  - Factor {}: {}'.format(j + 1, ratio))

    ratios = ratios.reshape((-1, 1))

    model.components_ *= ratios

    return model


def get_basis(model, variables):
    """
    Obtains the basis matrix for the given model and input variables.

    :param NMF model

    :param pd.Index[str] variables

    :rtype: pd.DataFrame
    """

    logging.info('Obtaining basis matrix')

    result = pd.DataFrame(
        model.components_.T,
        index=pd.Index(variables, name='variable'),
        columns=np.arange(model.n_components) + 1)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def get_scores(model, df):
    """
    Obtains scores from the given model using the given data.

    :param NMF model

    :param pd.DataFrame df

    :rtype: pd.DataFrame
    """

    logging.info('Obtaining scores')

    result = pd.DataFrame(
        model.transform(df),
        index=df.index,
        columns=np.arange(model.n_components) + 1)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def write_model(model, path):
    """
    Writes the given model to the given path.

    :param NMF model

    :param str path
    """

    logging.info('Writing model to {}'.format(path))

    sklearn_joblib.dump(model, path)


def write_basis(df, path):
    """
    Writes the given basis to the given path.

    :param pd.DataFrame df

    :param str path
    """

    logging.info('Writing basis to {}'.format(path))

    df.to_csv(path)


def write_scores(df, path):
    """
    Writes the given scores to the given path.

    :param pd.DataFrame df

    :param str path
    """

    logging.info('Writing scores to {}'.format(path))

    df.to_csv(path)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    model, data, samples = load_data(args.model_input, args.data_input,
                                     args.bootstrapped_sample_input)

    new_model = sparsify_model(
        model,
        samples,
        data.columns,
        lower_quantile_threshold=args.lower_quantile_threshold,
        upper_quantile=args.upper_quantile)

    basis = get_basis(new_model, data.columns)

    scores = get_scores(new_model, data)

    write_model(new_model, args.model_output)

    write_basis(basis, args.basis_output)

    write_scores(scores, args.score_output)
