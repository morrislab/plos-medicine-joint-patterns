"""
Conducts cross-validated NMF to determine the number of factors to use and
regularization constant (alpha) to use, using the bi-cross-validation procedure
outlined in Owen and Perry.

This particular version considers an input list of seeds rather than generating
them.
"""

import argparse
import feather
import itertools
import joblib
import logging
import numpy as np
import pandas as pd
import tqdm

from collections import namedtuple
from sklearn.decomposition import NMF
from sklearn.model_selection import KFold


def get_arguments():
    """Obtains command-line arguments."""

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--input',
        type=argparse.FileType('rU'),
        required=True,
        metavar='INPUT',
        help='read input data from CSV file %(metavar)s')

    parser.add_argument(
        '--seedlist',
        type=argparse.FileType('rU'),
        required=True,
        metavar='INPUT',
        help='read input seeds from text file %(metavar)s')

    parser.add_argument(
        '--output',
        required=True,
        metavar='OUTPUT',
        help='write Q2 values to Feather file %(metavar)s')

    parser.add_argument(
        '--init',
        choices=('random', 'nndsvd', 'nndsvda', 'nndsvdar'),
        default='nndsvd',
        metavar='INIT',
        help='use method %(metavar)s to initialize values (default: '
        '%(default)s)')

    parser.add_argument(
        '--l1-ratio',
        type=float,
        default=0.,
        metavar='L1-RATIO',
        help='use %(metavar)s as the regularization mixing parameter (use 0 '
        'to specify an L2 penalty, 1 to specify an L1 penalty, or a value in '
        '(0, 1) to specify a combination; default: %(default)s)')

    parser.add_argument(
        '--k',
        type=int,
        nargs='+',
        metavar='K',
        help='calculate Q2 for given ranks %(metavar)ss')

    parser.add_argument(
        '--alpha',
        type=float,
        nargs='+',
        metavar='ALPHA',
        help='calculate Q2 for given regularization constants %(metavar)s')

    parser.add_argument(
        '--alpha-base', type=float, metavar='ALPHA-BASE', default=2.)

    parser.add_argument(
        '--alpha-exp-start', type=int, metavar='ALPHA-EXP-START', default=-10)

    parser.add_argument(
        '--alpha-exp-end', type=int, metavar='ALPHA-EXP-END', default=10)

    parser.add_argument(
        '--folds',
        type=int,
        default=3,
        metavar='FOLDS',
        help='run bi-cross-validation with %(metavar)s folds (default: '
        '%(default)s)')

    parser.add_argument(
        '--cores',
        type=int,
        metavar='CORES',
        default=-1,
        help='use %(metavar)s cores for the analysis')

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


def load_data(handle):
    """
    Loads data from the given handle.

    :param io.file handle

    :rtype: pd.DataFrame
    """

    logging.info('Loading data')

    result = pd.read_csv(handle, index_col=0)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    return result


def load_seedlist(handle):
    """
    Loads seeds from the given handle.

    :param io.file handle

    :rtype: List[int]
    """

    logging.info('Loading seeds')

    stripped_data = (l.strip() for l in handle)

    filtered_data = (l for l in handle if l)

    seeds = [int(x) for x in filtered_data]

    logging.info('Loaded {} seeds'.format(len(seeds)))

    return seeds


def get_k(data, k, folds):
    """
    Determines the values of k to use.

    :param pd.DataFrame data

    :param List[int] k

    :param int folds

    :rtype: List[int]
    """

    result = k if k is not None else np.arange(
        np.floor(min(data.shape) * (1 - 1 / folds)) - 1, dtype=int) + 1

    logging.info('Setting k = {}'.format(', '.join(str(i) for i in result)))

    return list(result)


def get_alpha_range(base, start, end):
    """
    Obtains a range of regularization constants for the given base and start
    and end exponents inclusive.

    :param float base

    :param int start

    :param int end

    :rtype: List[float]
    """

    result = list(base**np.arange(start, end + 1))

    logging.info('Setting alpha values to test to {}'.format(result))

    return result


class InvalidFoldError(Exception):
    """
    An exception that is raised when the number of folds is not supported by
    the data.
    """

    def __init__(self):

        super().__init__('number of folds is not supported by the data')


def validate_k(data, k):
    """
    Validates that the number of folds is valid.

    :param pd.DataFrame data

    :param int k

    :raises InvalidFoldError: if the number of folds is not supported by the
        data
    """

    if k > min(data.shape):

        raise InvalidFoldError()


Parameters = namedtuple('Parameters', [
    'seed', 'k', 'alpha', 'fold', 'observation_train_ix',
    'observation_test_ix', 'measurement_train_ix', 'measurement_test_ix'
])


def _get_parameter_tuples(seed, k, alpha, folds, df):
    """
    Obtains a parameter tuple for the given seed, number of factors,
    regularization constant, and number of folds.

    In order, the parameters yielded are as follows as a named tuple:

    -   Seed (i.e., iteration)
    -   Number of factors
    -   Alpha
    -   Fold number
    -   Observation training set indices
    -   Observation test set indices
    -   Measurement training set indices
    -   Measurement test set indices

    :param int seed: the seed to use

    :param int k: the number of factors to test

    :param float alpha: the value of alpha to test

    :param int folds: the number of folds to split the data into

    :param pd.DataFrame df: the data to split

    :rtype: generator
    """

    np.random.seed(seed)

    fold_generator = KFold(n_splits=folds, shuffle=True)

    sample_folds = fold_generator.split(data)

    feature_folds = fold_generator.split(data.T)

    for f, ix in enumerate(zip(sample_folds, feature_folds)):

        observation_ix, measurement_ix = ix

        yield Parameters(seed, k, alpha, f + 1, observation_ix[0],
                         observation_ix[1], measurement_ix[0],
                         measurement_ix[1])


def _get_parameter_generator(seeds, k, alpha, folds, df):
    """
    Produces a generator that yields parameters for a single iteration.

    In order, the parameters yielded are as follows as a named tuple:

    -   Seed (i.e., iteration)
    -   Number of factors
    -   Alpha
    -   Fold number
    -   Observation training set indices
    -   Observation test set indices
    -   Measurement training set indices
    -   Measurement test set indices

    :param List[int] seeds

    :param List[int] k: the numbers of factors to test

    :param List[float] alpha: the values of alpha to test

    :param int folds: the number of folds to split the data into

    :param pd.DataFrame df: the data to split

    :rtype: generator
    """

    return itertools.chain(*(_get_parameter_tuples(s, k_, a, folds, df)
                             for s in seeds for k_ in k for a in alpha))


def _make_q2_result(seed, k, alpha, fold, q2):
    """
    Produces a result with the given values.

    :param int seed

    :param int k

    :param float alpha

    :param int fold

    :param float q2
    """

    return pd.DataFrame({
        'seed': [seed],
        'k': [k],
        'alpha': [alpha],
        'fold': [fold],
        'q2': [q2]
    })


def _cross_validate(df, init, l1_ratio, parameters):
    """
    Conducts cross-validation for the given data and parameters, returning a
    result containing a value of Q2.

    :param pd.DataFrame df

    :param str init

    :param float l1_ratio

    :param Parameters parameters

    :rtype: pd.DataFrame
    """

    # Split the data.

    test_data = data.iloc[parameters.observation_test_ix,
                          parameters.measurement_test_ix]

    # If the test data is all zeros, this will fail.

    denominator = (test_data**2).sum().sum()

    if denominator == 0.:

        return _make_q2_result(parameters.seed, parameters.k, parameters.alpha,
                               parameters.fold, np.nan)

    train_data = data.iloc[parameters.observation_train_ix,
                           parameters.measurement_train_ix]

    bottomleft_data = data.iloc[parameters.observation_test_ix,
                                parameters.measurement_train_ix]

    topright_data = data.iloc[parameters.observation_train_ix,
                              parameters.measurement_test_ix]

    # Set the seed.

    np.random.seed(parameters.seed)

    # Run NMF.

    nmf = NMF(n_components=parameters.k,
              alpha=parameters.alpha,
              tol=1e-6,
              max_iter=200,
              init=init,
              l1_ratio=l1_ratio)

    coefficients = nmf.fit_transform(train_data)

    test_reconstructions = bottomleft_data.values.dot(
        np.linalg.pinv(nmf.components_)).dot(np.linalg.pinv(coefficients)).dot(
            topright_data.values)

    q2 = 1 - ((test_data - test_reconstructions)**2).sum().sum() / (
        test_data**2).sum().sum()

    return _make_q2_result(parameters.seed, parameters.k, parameters.alpha,
                           parameters.fold, q2)


def cross_validate(data, folds, k, alpha, init, l1_ratio, cores, seeds):
    """
    Conducts cross-validation.

    :param pd.DataFrame data

    :param int folds

    :param List[int] k

    :param List[float] alpha

    :param str init

    :param float l1_ratio

    :param int cores

    :param List[int] seeds

    :rtype: pd.DataFrame
    """

    logging.info('Conducting cross-validation')

    # Obtain an iterator to better distribute jobs across all cores and better
    # measure progress.

    parameter_generator = _get_parameter_generator(seeds, k, alpha, folds,
                                                   data)

    # Calculate the number of jobs to perform.

    n_jobs = len(seeds) * len(k) * len(alpha) * folds

    progress = tqdm.tqdm(parameter_generator, total=n_jobs, mininterval=1.)

    multiprocess = cores != 1 or (cores == -1 and joblib.cpu_count() == 1)

    logging.info('Multiprocessing: {}'.format(multiprocess))

    result = joblib.Parallel(n_jobs=cores)(
        joblib.delayed(_cross_validate)(data, init, l1_ratio, p)
        for p in progress) if multiprocess else (_cross_validate(data, init,
                                                                 l1_ratio, p)
                                                 for p in progress)

    logging.info('Concatenating results')

    return pd.concat(result)


def write_output(q2, filename):
    """
    Writes the given data to the given Feather output.

    :param pd.DataFrame q2

    :param str filename
    """

    logging.info('Writing output to {}'.format(filename))

    feather.write_dataframe(q2, filename)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Load the data.

    data = load_data(args.input)

    # Load the list of seeds.

    seedlist = load_seedlist(args.seedlist)

    # Determine the number of ranks to use.

    k = get_k(data, args.k, args.folds)

    validate_k(data, args.folds)

    # Determine values of alpha to test.

    alpha = args.alpha or get_alpha_range(
        args.alpha_base, args.alpha_exp_start, args.alpha_exp_end)

    # Conduct cross-validated NMF.

    q2 = cross_validate(
        data,
        folds=args.folds,
        k=k,
        alpha=alpha,
        init=args.init,
        l1_ratio=args.l1_ratio,
        cores=args.cores,
        seeds=seedlist)

    # Write the output.

    write_output(q2, args.output)
