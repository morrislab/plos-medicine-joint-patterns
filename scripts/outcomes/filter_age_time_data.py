"""
Filters age of and time to diagnosis information to a given cohort of patients.
"""

import argparse
import feather
import logging
import pandas as pd


def get_arguments():
    """Obtains command-line arguments."""

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--age-time-input',
        type=argparse.FileType('r'),
        metavar='AGETIME',
        required=True,
        help='read age and time information from Feather file %(metavar)s')

    parser.add_argument(
        '--data-input',
        type=argparse.FileType('rU'),
        metavar='DATA',
        required=True,
        help='read cohort data from a CSV file %(metavar)s')

    parser.add_argument(
        '--output',
        required=True,
        metavar='OUTPUT',
        help='write output to a Feather file %(metavar)s')

    parser.add_argument(
        '--log',
        metavar='LOG',
        help='write logging information to %(metavar)s')

    return parser.parse_args()


def configure_logging(log=None):
    """Configures logging."""

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


def load_data(age_time_handle, data_handle):
    """
    Loads data from given handles for age and time data and cohort data.

    :param io.file age_time_handle

    :param io.file data_handle

    :rtype Tuple[pd.DataFrame, pd.DataFrame]
    """

    logging.info('Loading age and time data from {}'.format(
        age_time_handle.name))

    age_time_data = feather.read_dataframe(age_time_handle.name)

    logging.info('Loaded a table with shape {}'.format(age_time_data.shape))

    logging.info('Loading cohort data from {}'.format(data_handle.name))

    cohort_data = pd.read_csv(data_handle)

    logging.info('Loaded a table with shape {}'.format(cohort_data.shape))

    return age_time_data, cohort_data


def filter_data(age_time_data, subject_ids):
    """
    Filters given age and time data to the given patients.

    :param pd.DataFrame age_time_data

    :param pd.Series[int] subject_ids

    :rtype pd.DataFrame
    """

    logging.info('Filtering age and time data')

    result = age_time_data[age_time_data['subject_id'].isin(subject_ids)]

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def write_output(df, filename):
    """
    Writes the given data frame to the given file.

    :param pd.DataFrame df

    :param str filename
    """

    logging.info('Writing output')

    feather.write_dataframe(df, filename)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    age_time_data, cohort_data = load_data(args.age_time_input,
                                           args.data_input)

    age_time_data.info()

    cohort_data.info()

    filtered_data = filter_data(age_time_data, cohort_data['patient_id'])

    logging.info('Selecting data')

    selected_data = filtered_data[[
        'subject_id', 'diagnosis_age_days', 'symptom_onset_to_diagnosis_days'
    ]]

    selected_data.info()

    write_output(selected_data, args.output)
