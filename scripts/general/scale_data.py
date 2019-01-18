"""Scales the data to unit variance."""

import argparse
import logging
import pandas as pd


def get_arguments():
    """Obtains command-line arguments."""

    parser = argparse.ArgumentParser()

    parser.add_argument('--input', type=argparse.FileType('rU'), required=True)

    parser.add_argument('--output', required=True)

    parser.add_argument('--shift', action='store_true', default=False)

    parser.add_argument('--scale', action='store_true', default=False)

    parser.add_argument('--squeeze', action='store_true', default=False,
                        help='compress values so that they fit in the range [0, 1]')

    parser.add_argument('--parameter-output', required=True)

    parser.add_argument('--log')

    args = parser.parse_args()

    if args.squeeze and (args.shift or args.scale):

        parser.error(
            '--squeeze cannot be specified with --shift and/or --scale')

    return parser.parse_args()


def configure_logging(log=None):
    """Configures logging."""

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


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Load the data.

    logging.info('Loading data')

    data = pd.read_csv(args.input, index_col=0)

    logging.debug('Loaded a {} x {} matrix'.format(*data.shape))

    # Calculate the shifts for each variable.

    logging.info('Calculating shifts')

    shift = -data.mean()

    if not args.shift:

        shift.iloc[:] = 0.

    # Calculate the scales for each variable.

    logging.info('Calculating scales')

    scale = 1. / data.std()

    if not args.scale:

        scale.iloc[:] = 1.

    # Transform the data.

    logging.info('Transforming data')

    data = (data + shift) * scale

    # Squeeze the data.

    if args.squeeze:

        logging.info('Squeezing data to [0, 1]')

        min_values = data.min()

        ranges = data.max() - data.min()

        data = (data - min_values) / ranges

    # Write the data.

    logging.info('Writing outputs')

    data.to_csv(args.output)

    parameter_dict = {'scale': scale, 'shift': shift}

    if args.squeeze:

        parameter_dict['squeeze_shift'] = -min_values

        parameter_dict['squeeze_scale'] = 1. / ranges

    parameter_df = pd.DataFrame(parameter_dict)

    parameter_df.to_csv(args.parameter_output)

    logging.debug('Done')
