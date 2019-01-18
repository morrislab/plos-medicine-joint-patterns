"""
Combines bases into one for interpretability purposes.
"""

import argparse
import functools
import logging
import pandas as pd


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--basis-inputs', type=argparse.FileType('rU'), required=True,
        nargs='+')

    parser.add_argument(
        '--scaling-parameter-inputs', type=argparse.FileType('rU'), nargs='+')

    parser.add_argument('--output', required=True)

    parser.add_argument('--log')

    result = parser.parse_args()

    if result.scaling_parameter_inputs and len(
            result.scaling_parameter_inputs) != len(result.basis_inputs) - 1:

        parser.error(
            'the number of --scaling-parameter-inputs must be 1 less than the '
            'number of --basis-inputs')

    return result


def configure_logging(log=None):
    """
    Configures logging.

    :param bool log
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


def load_basis(handle):
    """
    Loads a basis matrix from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading basis matrix from {}'.format(handle.name))

    result = pd.read_csv(handle, index_col=0)

    result.index = result.index.astype(str)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def load_parameters(handle):
    """
    Loads scaling parameters from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading scaling parameters from {}'.format(handle.name))

    result = pd.read_csv(handle, index_col=0)

    result.index = result.index.astype(str)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def load_files(basis_handles, parameter_handles):
    """
    Loads basis matrices and parameters from the given handles.

    :param list[io.file] basis_handles

    :param list[io.file] parameter_handles

    :rtype tuple[list[pd.DataFrame], list[pd.DataFrame]]
    """

    logging.info('Loading basis matrices')

    bases = [load_basis(handle) for handle in basis_handles]

    logging.info('Loading scaling parameters')

    parameters = [load_parameters(handle) for handle in parameter_handles]

    return bases, parameters


def scale_bases(bases, scaling_parameters):
    """
    Scales the given bases using the given scaling parameters.

    :param list[pd.DataFrame] bases

    :param list[pd.DataFrame] scaling_parameters

    :rtype list[pd.DataFrame]
    """

    assert len(bases) == len(scaling_parameters) + 1

    logging.info('Scaling bases')

    b_sp_iter = zip(bases[:-1], scaling_parameters)

    new_bases = [b * sp['scale'] for b, sp in b_sp_iter] + bases[-1:]

    return new_bases


def combine_bases(bases):
    """
    Combines the given bases together.

    :param list[pd.DataFrame] bases

    :rtype pd.DataFrame
    """

    logging.info('Combining bases')

    result = functools.reduce(pd.DataFrame.dot, bases)

    logging.info('Result is a basis matrix with shape {}'.format(result.shape))

    return result


def write_output(basis, filename):
    """
    Writes the given basis to the given filename.

    :param pd.DataFrame basis

    :param str filename
    """

    logging.info('Writing output to {}'.format(filename))

    basis.to_csv(filename)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    bases, scaling_parameters = load_files(
        args.basis_inputs, args.scaling_parameter_inputs)

    if scaling_parameters:

        bases = scale_bases(bases, scaling_parameters)

    combined_basis = combine_bases(bases)

    write_output(combined_basis, args.output)

    logging.info('Done')
