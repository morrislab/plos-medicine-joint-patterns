"""
Generates data for running forward stepwise regression.
"""

import feather
import functools as ft
import pandas as pd

from click import *
from collections import namedtuple
from logging import *
from typing import *

Data = namedtuple(
    'Data',
    'patient_filter dai_scores medications age_time clusters localizations '
    'diagnoses')


def load_optional_data(path: str, description: str) -> pd.DataFrame:
    """
    Loads optional data.

    Args:
        path: The path to the data.
        description: The description of the data.

    Returns:
        The loaded data.
    """

    if path is None:

        return None

    info('Loading {}'.format(description))

    df = pd.read_csv(path)

    info('Result: {}'.format(df.shape))

    return df


def load_data(*,
              filter_path: str,
              dai_path: str,
              medication_path: str,
              age_time_path: str,
              cluster_path: str,
              localization_path: str,
              diagnosis_path: str) -> Data:
    """
    Loads data from the given inputs.

    Args:
        filter_path: The path to the patient filter.
        dai_path: The path to disease activity indicator scores.
        medication_path: The path to medication information.
        age_time_path: The path to age/time information.
        cluster_path: The path to cluster information.
        localization_path: The path to localization information.
        diagnosis_path: The path to diagnoses.

    Returns:
        Patient filter, disease activity scores, medications, age and time
        information, cluster assignments, localizations, and diagnoses.
    """

    info('Loading patient filter')

    df_patient_filter = pd.read_csv(filter_path)

    info('Result: {}'.format(df_patient_filter.shape))

    info('Loading disease activity indicator scores')

    df_dai_scores = pd.read_csv(dai_path)

    info('Result: {}'.format(df_dai_scores.shape))

    info('Loading medications')

    df_medications = feather.read_dataframe(medication_path)

    info('Result: {}'.format(df_medications.shape))

    info('Loading age and time information')

    df_age_time = feather.read_dataframe(age_time_path)

    info('Result: {}'.format(df_age_time.shape))

    df_clusters = load_optional_data(cluster_path, 'clusters')

    df_localization = load_optional_data(localization_path, 'localizations')

    df_diagnoses = load_optional_data(diagnosis_path, 'diagnoses')

    return Data(df_patient_filter, df_dai_scores, df_medications, df_age_time,
                df_clusters, df_localization, df_diagnoses)


FilteredData = namedtuple(
    'FilteredData',
    'dai_scores medications age_time clusters localizations diagnoses')


def filter_data_to_patients(data: Data) -> FilteredData:
    """
    Filters the given data to patients included in this study.

    Args:
        The data to filter.

    Returns:
        The filtered data.
    """

    subject_ids = data.patient_filter.loc[data.patient_filter['all_combined']
                                          == True, 'subject_id']

    df_dai_scores = data.dai_scores.loc[data.dai_scores['subject_id'].isin(
        subject_ids)]

    df_medications = data.medications.loc[data.medications['subject_id'].isin(
        subject_ids)]

    df_age_time = data.age_time.loc[data.age_time['subject_id'].isin(
        subject_ids)]

    df_clusters = data.clusters.loc[data.clusters['subject_id'].isin(
        subject_ids)] if data.clusters is not None else None

    df_localizations = data.localizations.loc[
        data.localizations['subject_id']
        .isin(subject_ids)] if data.localizations is not None else None

    df_diagnoses = data.diagnoses.loc[data.diagnoses['subject_id'].isin(
        subject_ids)] if data.diagnoses is not None else None

    return FilteredData(df_dai_scores, df_medications, df_age_time,
                        df_clusters, df_localizations, df_diagnoses)


def filter_data_to_visit(data: FilteredData, visit: int) -> FilteredData:
    """
    Filters the given data to the given visit.

    Disease activity scores will be filtered up to the visit of interest.

    Other data sets will be filtered to the visit of interest.

    Args:
        data: The data to filter.
        visit: The visit to consider.

    Returns:
        The filtered data.
    """

    df_dai_scores = data.dai_scores.loc[data.dai_scores['visit_id'] <=
                                        visit].copy()

    df_dai_scores['visit_id'] = df_dai_scores['visit_id'].astype(int)

    df_medications = data.medications.loc[data.medications['visit_id'] ==
                                          visit].drop(
                                              'visit_id', axis=1)

    return FilteredData(df_dai_scores, df_medications, data.age_time,
                        data.clusters, data.localizations, data.diagnoses)


def reformat_medication_statuses(data: FilteredData) -> FilteredData:
    """
    Reformats medication statuses to binary indicators.

    Args:
        data: The data containing medication statuses to reformat.

    Returns:
        Data with reformatted medication statuses.
    """

    for j in data.medications.columns[data.medications.columns.str.contains(
            '_status$')]:

        data.medications[j] = (~(data.medications[j].isin(
            ['NONE', 'NEW']))).astype(int)

    return data


@command()
@option(
    '--filter-input',
    required=True,
    help='the CSV file to load the patient filter from')
@option('--dai-input', required=True, help='the CSV file to load scores from')
@option(
    '--medication-input',
    required=True,
    help='the CSV file to load medication information from')
@option(
    '--age-time-input',
    required=True,
    help='the CSV file to load age and time data from')
@option(
    '--visit', type=int, required=True, help='the visit to extract data for')
@option('--output', required=True, help='the Feather file to output data to')
@option(
    '--cluster-input', help='the CSV file to load cluster assignments from')
@option('--localization-input', help='the CSV file to load localizations from')
@option('--diagnosis-input', help='the CSV file to load diagnoses from')
@option(
    '--ignore', multiple=True, help='fields to ignore (multiple permitted)')
def main(filter_input, dai_input, medication_input, age_time_input, visit,
         output, cluster_input, localization_input, diagnosis_input, ignore):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Verify options.

    if localization_input is not None and cluster_input is None:

        raise UsageError(
            '--cluster-input must be specified with --localization-input')

    # Load the data.

    data = load_data(
        filter_path=filter_input,
        dai_path=dai_input,
        medication_path=medication_input,
        age_time_path=age_time_input,
        cluster_path=cluster_input,
        localization_path=localization_input,
        diagnosis_path=diagnosis_input)

    # Filter the data.

    info('Filtering data to patients included in study')

    data = filter_data_to_patients(data)

    info('Filtering data to visit')

    data = filter_data_to_visit(data, visit)

    # Reformat medication statuses.

    info('Reformat medication statuses')

    data = reformat_medication_statuses(data)

    # Merge data.

    info('Merging non-disease activity indicator data')

    merge_partial = ft.partial(
        pd.DataFrame.merge, on='subject_id', suffixes=['', '_y'])

    df_merged = ft.reduce(merge_partial,
                          (x
                           for x in [
                               data.medications, data.age_time, data.clusters,
                               data.localizations, data.diagnoses
                           ] if x is not None))

    df_merged.drop(
        df_merged.columns[df_merged.columns.str.endswith('_y')],
        axis=1,
        inplace=True)

    info('Reformatting disease activity indicator scores')

    df_dai_visit = data.dai_scores.loc[data.dai_scores['visit_id'] ==
                                       visit].drop(
                                           'visit_id', axis=1).copy()

    df_dai_visit.rename(columns={'PC2': 'dai'}, inplace=True)

    df_dai_past = data.dai_scores.loc[data.dai_scores['visit_id'] < visit]

    df_dai_past = df_dai_past.pivot(
        index='subject_id', columns='visit_id', values='PC2').reset_index()

    df_dai_past.rename(
        columns={
            j: 'dai_{}'.format(j)
            for j in df_dai_past.columns if isinstance(j, int)
        },
        inplace=True)

    info('Merging disease activity indicator scores')

    df_merged = ft.reduce(merge_partial,
                          [df_merged, df_dai_past, df_dai_visit])

    # Drop columns as necessary.

    if ignore:

        info('Dropping columns')

        df_merged.drop(list(ignore), axis=1, inplace=True)

    # Drop uninformative columns.

    info('Dropping uninformative columns')

    n_uniques = df_merged.nunique()

    to_drop = n_uniques.index[n_uniques < 2]

    info('Dropping columns: {!r}'.format(to_drop.tolist()))

    df_merged.drop(to_drop, axis=1, inplace=True)

    # Convert factors.

    info('Converting factors')

    for j in df_merged.columns:

        if df_merged[j].dtype == object:

            df_merged[j] = df_merged[j].astype('category')

    # Write output.

    info('Writing output')

    feather.write_dataframe(df_merged, output)


if __name__ == '__main__':
    main()