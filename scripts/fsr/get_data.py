"""
Extracts data for forward stepwise regression.
"""

import click
import feather
import pandas as pd

from logging import *
from typing import *


def filter_medications(df: pd.DataFrame,
                       visit: List[int],
                       blacklist: List[int]) -> pd.DataFrame:

    info('Filtering medications')

    y = df.loc[df['visit_id'].notnull() & df['visit_id'].isin(visit)]

    if blacklist:

        info('Dropping blacklisted medications')

        y = y.drop(blacklist, axis=1)

    return y


def filter_data(df_factor_scores: pd.DataFrame,
                df_dai_projections: pd.DataFrame,
                df_medications: pd.DataFrame,
                df_diagnoses: pd.DataFrame,
                df_age_times: pd.DataFrame) -> (pd.DataFrame, pd.DataFrame,
                                                pd.DataFrame, pd.DataFrame):

    info('Filtering data')

    patient_ids = df_factor_scores['subject_id']

    df_dai_projections = df_dai_projections.loc[df_dai_projections[
        'subject_id'].isin(patient_ids)]

    df_medications = df_medications.loc[df_medications['subject_id'].isin(
        patient_ids)]

    df_diagnoses = df_diagnoses.loc[df_diagnoses['subject_id'].isin(
        patient_ids)]

    df_age_times = df_age_times.loc[df_age_times['subject_id'].isin(
        patient_ids)]

    return (df_dai_projections, df_medications, df_diagnoses, df_age_times)


def _transform_medications(x: pd.Series) -> pd.Series:

    return ~(x.isin(['NONE', 'NEW']))


def transform_medications(df: pd.DataFrame) -> pd.DataFrame:

    info('Transforming medications')

    return df.set_index(
        ['subject_id', 'visit_id']).apply(_transform_medications).reset_index()


def remove_uninformative_medications(df: pd.DataFrame) -> pd.DataFrame:

    info('Removing uninformative medications')

    patient_counts = df.set_index(['subject_id', 'visit_id']).sum()

    return df.drop(patient_counts.index[patient_counts < 1], axis=1)


def dummy_encode_diagnoses(df: pd.DataFrame) -> pd.DataFrame:

    info('Dummy-encoding diagnoses')

    df = df.set_index('subject_id')

    df['diagnosis'] = df['diagnosis'].str.lower().str.replace(r'(\s+|-)', '_')

    return pd.get_dummies(df).reset_index()


def reformat_dai_projections(df: pd.DataFrame) -> pd.DataFrame:

    info('Reformatting DAI projections')

    import IPython
    IPython.embed()
    raise Exception()


@click.command()
@click.option(
    '--projection-input',
    required=True,
    help='read DAI projections from CSV file PROJECTION_INPUT')
@click.option(
    '--medication-input',
    required=True,
    help='read medications from Feather file MEDICATION_INPUT')
@click.option(
    '--score-input',
    required=True,
    help='read factor scores from CSV file SCORE_INPUT')
@click.option(
    '--diagnosis-input',
    required=True,
    help='read diagnoses from CSV file DIAGNOSIS_INPUT')
@click.option(
    '--age-time-input',
    required=True,
    help='read age and time data from Feather file AGE_TIME_INPUT')
@click.option(
    '--visit',
    required=True,
    type=int,
    multiple=True,
    help='extract information for visits VISIT')
@click.option(
    '--ignore-medication',
    multiple=True,
    help='ignore the medication status given by IGNORE_MEDICATION')
@click.option(
    '--output', required=True, help='output data to Feather file OUTPUT')
def main(projection_input, medication_input, score_input, diagnosis_input,
         age_time_input, visit, ignore_medication, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Read all data.

    info('Reading DAI projections from {}'.format(projection_input))

    dai_projections = pd.read_csv(projection_input)

    dai_projections.info()

    info('Reading medications from {}'.format(medication_input))

    medications = feather.read_dataframe(medication_input)

    medications.info()

    info('Reading factor scores from {}'.format(score_input))

    factor_scores = pd.read_csv(score_input)

    factor_scores.info()

    info('Reading diagnoses from {}'.format(diagnosis_input))

    diagnoses = pd.read_csv(diagnosis_input)[['subject_id', 'diagnosis']]

    diagnoses.info()

    info('Reading age and time information from {}'.format(age_time_input))

    age_times = feather.read_dataframe(age_time_input)[[
        'subject_id', 'diagnosis_age_days', 'symptom_onset_to_diagnosis_days'
    ]]

    age_times.info()

    # Filter the medications.

    medications = filter_medications(medications, visit,
                                     list(ignore_medication))

    # Filter the DAI scores.

    info('Filtering DAI scores')

    dai_projections = dai_projections.loc[dai_projections['visit_id'].isin(
        [min(visit) - 1] + list(visit))]

    # Filter ages and times.

    info('Filtering ages of and times to diagnosis')

    age_times = age_times.loc[age_times['diagnosis_age_days'].notnull(
    ) & age_times['symptom_onset_to_diagnosis_days'].notnull()]

    # Filter the data.

    dai_projections, medications, diagnoses, age_times = filter_data(
        factor_scores, dai_projections, medications, diagnoses, age_times)

    # Transform the medication statuses.

    medications = transform_medications(medications)

    # Remove uninformative medications.

    medications = remove_uninformative_medications(medications)

    # Transform the diagnoses.

    diagnoses = dummy_encode_diagnoses(diagnoses)

    # Reformat the DAI projections.

    import IPython
    IPython.embed()
    raise Exception()

    reformatted_dai_projections = reformat_dai_projections(dai_projections)


if __name__ == '__main__':

    main()