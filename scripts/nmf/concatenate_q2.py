"""
Concatenates cross-validation runs together.
"""

import argparse
import feather
import logging
import pandas as pd


def get_arguments():
    """Obtains command-line arguments."""

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--inputs',
        required=True,
        nargs='+',
        metavar='INPUT',
        help='read Q2 inputs from Feather files %(metavar)ss')

    parser.add_argument(
        '--output',
        required=True,
        metavar='OUTPUT',
        help='write the output to Feather file %(metavar)s')

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


def _load_data(path):
    """
    Loads data from the given path.

    :param str path

    :rtype: pd.DataFrame
    """

    logging.info('Loading {}'.format(path))

    result = feather.read_dataframe(path)

    logging.info('Loaded a table with shape {}'.format(result.shape))

    return result


def load_data(paths):
    """
    Loads data from the given paths.

    :param List[str] paths

    :rtype: List[pd.DataFrame]
    """

    logging.info('Loading data')

    result = [_load_data(p) for p in paths]

    return result


def concatenate_data(dfs):
    """
    Concatenates the given data together.

    :param List[pd.DataFrame] dfs

    :rtype: pd.DataFrame
    """

    logging.info('Concatenating data')

    result = pd.concat(dfs)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def write_output(df, path):
    """
    Writes the given table to the given path.

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

    q2 = load_data(args.inputs)

    concatenated = concatenate_data(q2)

    write_output(concatenated, args.output)
