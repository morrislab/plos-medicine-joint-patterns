"""
Projects clinical measurements to clinical-cytokine PC 2.
"""

import argparse
import feather
import logging
import pandas as pd


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--original-prescaled-input',
        type=argparse.FileType('rU'),
        metavar='PRESCALED-INPUT',
        required=True,
        help='determine scaling parameters from CSV file %(metavar)s')

    parser.add_argument(
        '--original-loading-input',
        type=argparse.FileType('rU'),
        metavar='LOADING-INPUT',
        required=True,
        help=('project to clinical-cytokine PC 2 from loadings in CSV file '
              ' %(metavar)s'))

    parser.add_argument(
        '--measurement-input',
        metavar='MEASUREMENT-INPUT',
        required=True,
        help='project measurements from Feather file %(metavar)s')

    parser.add_argument(
        '--output',
        required=True,
        metavar='OUTPUT',
        help='write output to CSV file %(metavar)s')

    parser.add_argument(
        '--loadings-column-index',
        type=int,
        default=1,
        metavar='LOADING-INDEX',
        help=('extract relevant PC 2 loadings from column %(metavar)s '
              '(default: %(default)s)'))

    parser.add_argument(
        '--log',
        metavar='LOG',
        help='write logging information to %(metavar)s')

    return parser.parse_args()


def configure_logging(log=None):
    """
    Configures logging.

    :param str log: the path to log to
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


def _load_data(handle, index_col, what):
    """
    Loads data from the given handle.

    :param io.file handle

    :param {int, List[int]} index_col

    :param str what

    :rtype pd.DataFrame
    """

    logging.info('Loading {}'.format(what))

    out = pd.read_csv(handle, index_col=index_col)

    logging.info('Result is a table with shape {}'.format(out.shape))

    return out


def load_data(prescaled_handle, loading_handle, measurement_path):
    """
    Loads prescaled original data, original loadings, and input measurements
    from the given handles.

    :param io.file prescaled_handle

    :param io.file loading_handle

    :param str measurement_path

    :rtype Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]
    """

    logging.info('Loading prescaled data')

    prescaled = _load_data(
        prescaled_handle, index_col=0, what='prescaled data')

    loadings = _load_data(loading_handle, index_col=0, what='loadings')

    measurements = feather.read_dataframe(measurement_path).dropna(
        subset=['visit_id']).set_index(['subject_id', 'visit_id'])

    measurements.info()

    # measurements = _load_data(
    #     measurement_handle, index_col=[0, 1], what='measurement data')

    return prescaled, loadings, measurements


def filter_loadings(df, index):
    """
    Filters loadings in the given table to PC 2.

    :param pd.DataFrame df

    :param int index

    :rtype pd.DataFrame
    """

    logging.info('Filtering loadings')

    result = df.iloc[:, [index]]

    result = result.loc[result.iloc[:, 0] != 0.]

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def select_common_data(original_df, loading_df, df):
    """
    Selects common measurements in the given original data, loadings, and data
    to project.

    :param pd.DataFrame original_df

    :param pd.DataFrame loading_df

    :param pd.DataFrame df

    :rtype Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]
    """

    logging.info('Selecting common data')

    common_fields = original_df.columns.intersection(
        loading_df.index).intersection(df.columns)

    if common_fields.size < 1:

        raise ValueError('no common fields to use')

    logging.info('Selecting fields: {!r}'.format(common_fields.tolist()))

    original_result = original_df[common_fields]

    logging.info('Resulting original data is a table with shape {}'.format(
        original_result.shape))

    loading_result = loading_df.loc[common_fields]

    logging.info('Resulting loadings is a table with shape {}'.format(
        loading_result.shape))

    result = df[common_fields]

    logging.info('Resulting data is a table with shape {}'.format(
        result.shape))

    return original_result, loading_result, result


def scale_data(df, original_df):
    """
    Scales the given data relative to the given original data.

    :param pd.DataFrame df

    :param pd.DataFrame original_df

    :rtype pd.DataFrame
    """

    logging.info('Scaling data')

    shifts = original_df.mean()

    scales = original_df.std()

    return (df - shifts) / scales


def remove_na(df):
    """
    Removes patient-visits whose data contains only missing values and fills in
    the remaining missing values with 0.

    :param pd.DataFrame df

    :rtype pd.DataFrame
    """

    logging.info('Cleaning missing values')

    result = df.dropna(how='all').copy()

    result.fillna(0., inplace=True)

    logging.info('Result is a table with shape {}'.format(df.shape))

    return result


def project_data(df, loadings):
    """
    Calculates scores from the given data and given loadings.

    :param pd.DataFrame df

    :param pd.DataFrame loadings

    :rtype pd.DataFrame
    """

    logging.info('Projecting data to scores')

    result = df.dot(loadings)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def write_output(df, path):
    """
    Writes the given table to the given path.

    :param pd.DataFrame df

    :param str path
    """

    logging.info('Writing output')

    df.to_csv(path)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    original_data, loadings, data = load_data(args.original_prescaled_input,
                                              args.original_loading_input,
                                              args.measurement_input)

    loadings = filter_loadings(loadings, args.loadings_column_index)

    original_data, loadings, data = select_common_data(original_data, loadings,
                                                       data)

    data = scale_data(data, original_data)

    data = remove_na(data)

    scores = project_data(data, loadings)

    write_output(scores, args.output)
