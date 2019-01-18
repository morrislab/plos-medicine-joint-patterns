"""
Orders the clusters from head to toe.
"""

import argparse
import logging
import numpy as np
import pandas as pd
from sklearn.decomposition import NMF
from sklearn.externals import joblib


def get_arguments():
    """
    Obtains command-line arguments.
    """

    parser = argparse.ArgumentParser()

    parser.add_argument('--model-input', required=True)

    parser.add_argument(
        '--basis-input', type=argparse.FileType('rU'), required=True)

    parser.add_argument(
        '--score-input', type=argparse.FileType('rU'), required=True)

    parser.add_argument(
        '--joint-order-input', type=argparse.FileType('rU'), required=True)

    parser.add_argument('--model-output', required=True)

    parser.add_argument('--basis-output', required=True)

    parser.add_argument('--score-output', required=True)

    parser.add_argument('--log')

    return parser.parse_args()


def configure_logging(log=None):
    """
    Configures logging.

    :param bool log: whether to log to a file
    """

    if log:

        logging.basicConfig(level=logging.DEBUG, filename=log,
                            filemode='w',
                            format='%(asctime)s %(levelname)-8s %(message)s')

        console = logging.StreamHandler()

        console.setLevel(logging.INFO)

        console.setFormatter(logging.Formatter('%(message)s'))

        logging.getLogger().addHandler(console)

    else:

        logging.basicConfig(level=logging.INFO, format='%(message)s')


def load_model(filename):
    """
    Loads the model from the given file.

    :param str filename

    :rtype NMF
    """

    logging.info('Loading model')

    return joblib.load(filename)


def load_basis(handle):
    """
    Loads the basis from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading basis')

    result = pd.read_csv(handle, index_col=0)

    result.index = result.index.astype(str)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    return result


def load_scores(handle):
    """
    Loads scores from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading scores')

    result = pd.read_csv(handle, index_col=0)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    return result


def load_joint_order(handle):
    """
    Loads a joint order from the given handle.

    :param io.file handle

    :rtype list[str]
    """

    logging.info('Loading joint order')

    result = [line.strip() for line in handle]

    logging.info('Loaded {} joints'.format(len(result)))

    return result


def get_factor_order(basis, joint_order):
    """
    Obtains an ordering for old factors/clusters using the given basis matrix
    and joint order.

    :param pd.DataFrame basis

    :param list[str] joint_order

    :rtype np.array[int]
    """

    logging.info('Generating assignment map')

    joint_ranks = pd.Series(np.arange(len(joint_order)) + 1, index=joint_order)

    sum_ranks = joint_ranks[basis.index].values @ basis

    return np.argsort(sum_ranks)


def reorder_model(model, factor_order):
    """
    Modifies the given model given a factor order.

    :param NMF model

    :param np.array[int] factor_order
    """

    logging.info('Modifying model')

    model.components_ = model.components_[factor_order]


def reorder_basis(basis, factor_order):
    """
    Modifies the given basis given a factor order.

    :param pd.DataFrame basis

    :param np.array[int] factor_order

    :rtype pd.DataFrame
    """

    logging.info('Re-ordering basis')

    result = basis.iloc[:, factor_order]

    result.columns = (np.arange(result.shape[1]) + 1).astype(str)

    return result


def reorder_scores(scores, factor_order):
    """
    Modifies the given scores given a factor order.

    :param pd.DataFrame scores

    :param np.array[int] factor_order

    :rtype pd.DataFrame
    """

    logging.info('Re-ordering scores')

    result = scores.iloc[:, factor_order]

    result.columns = (np.arange(result.shape[1]) + 1).astype(str)

    return result


def write_model(model, filename):
    """
    Writes the given model to the given file.

    :param NMF model

    :param str filename
    """

    logging.info('Writing model to {}'.format(filename))

    joblib.dump(model, filename)


def write_basis(basis, filename):
    """
    Writes the given basis to the given file.

    :param pd.DataFrame basis

    :param str filename
    """

    logging.info('Writing basis to {}'.format(filename))

    basis.to_csv(filename)


def write_scores(scores, filename):
    """
    Writes the given scores to the given file.

    :param pd.DataFrame scores

    :param str filename
    """

    logging.info('Writing scores to {}'.format(filename))

    scores.to_csv(filename)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Load all data.

    model = load_model(args.model_input)

    basis = load_basis(args.basis_input)

    scores = load_scores(args.score_input)

    joint_order = load_joint_order(args.joint_order_input)

    # Calculate a mapping from old assignment to new assignment.

    factor_order = get_factor_order(basis, joint_order)

    # Re-order everything.

    reorder_model(model, factor_order)

    basis = reorder_basis(basis, factor_order)

    scores = reorder_scores(scores, factor_order)

    # Write the output.

    write_model(model, args.model_output)

    write_basis(basis, args.basis_output)

    write_scores(scores, args.score_output)

    logging.info('Done')
