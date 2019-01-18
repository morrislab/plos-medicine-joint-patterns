"""
Generates a bunch of seeds for downstream use.
"""

import argparse
import logging
import numpy as np
import pandas as pd


def get_arguments():
    """Obtains command-line arguments."""

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--output-prefix',
        required=True,
        metavar='PATH',
        help='write seeds to text files prefixed by path %(metavar)s')

    parser.add_argument(
        '--jobs',
        type=int,
        required=True,
        metavar='JOBS',
        help='generate seeds for %(metavar)s jobs')

    parser.add_argument(
        '--iterations-per-job',
        type=int,
        required=True,
        metavar='ITERATIONS',
        help='generate seeds for %(metavar)s iterations per job')

    parser.add_argument(
        '--seed',
        type=int,
        default=290348203,
        metavar='SEED',
        help='set the seed to %(metavar)s')

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


def get_seeds(seed, jobs, iterations_per_job):
    """
    Obtains seeds for the given initial seed, the number of jobs, and number of
    iterations per job.

    :param int seed

    :param int jobs

    :param int iterations_per_job

    :rtype List[List[int]]
    """

    n_seeds = jobs * iterations_per_job

    result = pd.Series([], dtype=int)

    current_seed = seed

    while result.shape[0] < n_seeds:

        seeds = pd.Series(
            np.random.RandomState(current_seed).get_state()[1], dtype=int)

        result = pd.Series(pd.concat([result, seeds]).unique(), dtype=int)

        current_seed = result.iloc[-1]

    return [
        result.iloc[(i * iterations_per_job):((i + 1) * iterations_per_job)]
        for i in range(jobs)
    ]


def write_outputs(seeds, prefix):
    """
    Writes the given seeds to text files starting with the given prefix.

    :param List[List[int]] seeds

    :param str prefix
    """

    for i, s in enumerate(seeds):

        path = '{}{}.txt'.format(prefix, i + 1)

        logging.info('Writing output to {}'.format(path))

        with open(path, 'w') as handle:

            handle.write('\n'.join(str(x) for x in s))


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    seeds = get_seeds(args.seed, args.jobs, args.iterations_per_job)

    write_outputs(seeds, args.output_prefix)
