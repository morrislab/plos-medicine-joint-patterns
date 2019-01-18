"""
Generates bootstrapped samples of NMF basis matrix entries.
"""

import argparse
import feather
import itertools
import joblib
import logging
import numpy as np
import pandas as pd
import tqdm

from sklearn.decomposition import NMF
from sklearn.externals import joblib as sklearn_joblib
from sklearn.utils import resample


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--data-input',
        type=argparse.FileType('rU'),
        required=True,
        metavar='DATA-INPUT',
        help='read input data from CSV file %(metavar)s')

    parser.add_argument(
        '--model-input',
        required=True,
        metavar='MODEL-INPUT',
        help='read the base model from Pickle file %(metavar)s')

    parser.add_argument(
        '--iterations',
        type=int,
        default=2000,
        help=('run the analysis with %(metavar)s bootstraps (default: '
              '%(default)s)'))

    parser.add_argument(
        '--output',
        required=True,
        metavar='OUTPUT',
        help='output samples to Feather file %(metavar)s')

    parser.add_argument(
        '--seed',
        type=int,
        default=33767308,
        metavar='SEED',
        help='initialize the analysis with the given seed %(metavar)s')

    parser.add_argument(
        '--processes',
        type=int,
        default=-1,
        metavar='CORES',
        help='run the analysis with %(metavar)s processes')

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


def load_data(data_handle, model_path):
    """
    Loads data and a model from the given handles.

    :param io.file data_handle

    :param io.file model_path

    :rtype pd.DataFrame
    """

    logging.info('Loading data')

    result = pd.read_csv(data_handle, index_col=0)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    logging.info('Loading model')

    model = sklearn_joblib.load(model_path)

    return result, model


def get_seeds(seed, iterations):
    """
    Obtains seeds for the given number of iterations.

    :param int seed

    :param int iterations

    :rtype np.array<int>
    """

    logging.info('Generating seeds')

    np.random.seed(seed)

    int_info = np.iinfo(np.uint32)

    return np.random.randint(0, int_info.max, iterations)


def bootstrap_nmf(df, model, seed):
    """
    Runs a single bootstrap of NMF with the given table, NMF model, and seed.

    :param pd.DataFrame df

    :param NMF model

    :param int seed

    :rtype pd.DataFrame
    """

    k = model.n_components

    k_range = np.arange(k)

    resampled_df = resample(df, random_state=seed)

    np.random.seed(seed)

    nmf = NMF(n_components=k,
              init=model.init,
              l1_ratio=model.l1_ratio,
              alpha=model.alpha)

    nmf.fit(resampled_df)

    # Create a mapping: original -> bootstrapped factors.

    factor_map = {}

    remaining_bootstrapped_factors = set(range(k))

    # Generate a table of factors and variables to look at, in descending order
    # of basis matrix entry. This guarantees that better defined factors are
    # taken care of first.

    original_index_order = pd.melt(
        pd.DataFrame(
            model.components_,
            index=pd.Index(
                np.arange(
                    k, dtype=int), name='factor')).reset_index(),
        id_vars='factor',
        var_name='variable',
        value_name='basis')

    original_index_order.sort_values('basis', ascending=False, inplace=True)

    for _, row in original_index_order.iterrows():

        original_factor = row['factor']

        max_boostrapped_factor = nmf.components_[:, row['variable']].argmax()

        if (max_boostrapped_factor in remaining_bootstrapped_factors and
                original_factor not in factor_map):

            factor_map[original_factor] = max_boostrapped_factor

            remaining_bootstrapped_factors.remove(max_boostrapped_factor)

            continue

        if not remaining_bootstrapped_factors:

            break

    # If we still have unmapped factors, we have no choice but to map them by
    # distance between basis matrix entries. Scale so that the L2 norm is one
    # before proceeding.

    if remaining_bootstrapped_factors:

        unmapped_original = set(range(k)) - set(factor_map.keys())

        # If there's only one unmapped factor, just assign the mapping.

        if len(unmapped_original) == 1:

            factor_map[unmapped_original.pop(
            )] = remaining_bootstrapped_factors.pop()

        # Otherwise, calculate distances and map based on that.

        else:

            original_basis_vectors = {
                i: model.components_[i] /
                np.sqrt(np.sum(model.components_[i]**2))
                for i in unmapped_original
            }

            bootstrapped_basis_factors = {
                j:
                nmf.components_[j] / np.sqrt(np.sum(nmf.components_[j]**2))
                for j in remaining_bootstrapped_factors
            }

            distances = pd.DataFrame.from_records(
                [(i, j, np.sqrt(
                    np.sum((original_basis_vectors[i] -
                            bootstrapped_basis_factors[j])**2)))
                 for i in unmapped_original
                 for j in remaining_bootstrapped_factors],
                columns=['original', 'bootstrapped', 'distance'])

            distances.sort_values('distance', ascending=False, inplace=True)

            for _, row in distances.iterrows():

                original_factor = int(row['original'])

                bootstrapped_factor = int(row['bootstrapped'])

                if (bootstrapped_factor in remaining_bootstrapped_factors and
                        original_factor not in factor_map):

                    factor_map[original_factor] = bootstrapped_factor

                    remaining_bootstrapped_factors.remove(bootstrapped_factor)

                    if not remaining_bootstrapped_factors:

                        break

    # Generate a mapping from bootstrapped factors to original factors.

    reverse_map = [v for _, v in sorted(factor_map.items())]

    ix = pd.MultiIndex.from_arrays(
        [np.tile(seed, k), k_range + 1], names=['seed', 'factor'])

    return pd.DataFrame(
        nmf.components_[reverse_map], index=ix, columns=df.columns)


def reshape_samples(df):
    """
    Reshapes samples in the given table.

    :param pd.DataFrame df

    :rtype pd.DataFrame
    """

    return pd.melt(
        df.reset_index(),
        id_vars=['seed', 'factor'],
        var_name='variable',
        value_name='loading')


def bootstrap(df, model, seeds, processes):
    """
    Bootstraps the NMF basis matrix using the given table, NMF model, and
    seeds.

    :param pd.DataFrame df

    :param NMF model

    :param Iterable[int] seeds

    :param int processes

    :rtype pd.DataFrame
    """

    logging.info('Running bootstrapped analysis')

    # samples = (bootstrap_nmf(df, model, seed)
    #            for seed in tqdm.tqdm(
    #                seeds, mininterval=1))

    samples = joblib.Parallel(n_jobs=processes)(joblib.delayed(bootstrap_nmf)(
        df, model, seed) for seed in tqdm.tqdm(
            seeds, mininterval=1))

    reshaped_samples = (reshape_samples(s) for s in samples)

    return pd.concat(reshaped_samples)


def write_output(df, path):
    """
    Writes the given samples to the given path.

    :param pd.DataFrame df

    :param str path
    """

    logging.info('Writing output')

    feather.write_dataframe(df, path)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    data, model = load_data(args.data_input, args.model_input)

    seeds = get_seeds(args.seed, args.iterations)

    samples = bootstrap(data, model, seeds, processes=args.processes)

    write_output(samples, args.output)
