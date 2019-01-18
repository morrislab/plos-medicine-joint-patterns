"""
Filters joint involvement data to treatment-naive patients diagnosed up to one
year after symptom onset who have joint involvement at baseline.

Patients must also not be withdrawn at any point from the study.
"""

import click
import feather
import pandas as pd

from logging import *


def load_data(basic_path: str,
              medication_path: str,
              joint_injection_path: str,
              joint_path: str) -> (pd.DataFrame, pd.DataFrame, pd.DataFrame,
                                   pd.DataFrame):
    """
    Loads data from the given paths.

    Returns:
        The loaded data.
    """

    info('Reading basic information from {}'.format(basic_path))

    basic_data = feather.read_dataframe(basic_path)

    basic_data.info()

    basic_data.set_index('subject_id', inplace=True)

    info('Reading medications from {}'.format(medication_path))

    medication_data = feather.read_dataframe(medication_path)

    medication_data.info()

    medication_data = medication_data.loc[medication_data['visit_id'] ==
                                          1].set_index('subject_id')

    info('Reading joint injections from {}'.format(joint_injection_path))

    joint_injection_data = feather.read_dataframe(joint_injection_path)

    joint_injection_data.info()

    joint_injection_data = joint_injection_data.loc[joint_injection_data[
        'visit_id'] == 1].set_index('subject_id')

    info('Reading joint involvements from {}'.format(joint_path))

    joint_data = feather.read_dataframe(joint_path)

    joint_data.info()

    return basic_data, medication_data, joint_injection_data, joint_data


def get_basic_masks(df: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains masks for the given basic data.

    Args:
        df: A table of basic information.

    Returns:
        The masks.
    """

    mask_sex = pd.notnull(df['sex'])

    info('{} patients had sex information'.format(mask_sex.sum()))

    mask_dx = pd.notnull(df['diagnosis_6_months'])

    info('{} patients had recorded diagnoses'.format(mask_dx.sum()))

    mask_withdrawn = ~(df['withdrawn'])

    info('{} patients were not withdrawn'.format(mask_withdrawn.sum()))

    mask_symptom_onset_age = (df['symptom_onset_age'] > 0) & (
        df['symptom_onset_age'] < 16)

    info('{} patients were between 0 and 16 years of age at symptom onset'.
         format(mask_symptom_onset_age.sum()))

    mask_onset_to_diagnosis = (df['symptom_onset_to_diagnosis_days'] >= 0) & (
        df['symptom_onset_to_diagnosis_days'] < 365)

    info(('{} patients were diagnosed between 0 days and before one year '
          'after symptom onset').format(mask_onset_to_diagnosis.sum()))

    mask_basic = (mask_sex & mask_dx & mask_withdrawn &
                  mask_symptom_onset_age & mask_onset_to_diagnosis)

    info('{} patients satisfied basic inclusion criteria'.format(
        mask_basic.sum()))

    return pd.DataFrame.from_items(
        [('sex', mask_sex), ('diagnosis', mask_dx),
         ('withdrawn', mask_withdrawn),
         ('symptom_onset_age', mask_symptom_onset_age),
         ('onset_to_diagnosis', mask_onset_to_diagnosis),
         ('basic_combined', mask_basic)])


def get_medication_masks(medication_df: pd.DataFrame,
                         joint_injection_df: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains masks for the given medication data and joint injection data.

    Args:
        df: A table of medications.

    Returns:
        The masks.
    """

    mask_dmards = medication_df['dmard_status'].isin(['NONE', 'NEW'])

    info('{} patients were not previously on DMARDs'.format(mask_dmards.sum()))

    mask_steroids = medication_df['steroid_status'].isin(['NONE', 'NEW'])

    info('{} patients were not previously on steroids'.format(
        mask_steroids.sum()))

    mask_ivig = medication_df['ivig_status'].isin(['NONE', 'NEW'])

    info('{} patients were not previously on IVIG'.format(mask_ivig.sum()))

    mask_biologics = medication_df['biologic_status'].isin(['NONE', 'NEW'])

    info('{} patients were not previously on biologics'.format(
        mask_biologics.sum()))

    mask_joint_injections = (
        joint_injection_df['injection_status'] == 'NONE') | (
            joint_injection_df['days_max'] < 0)

    info('{} patients had no joint injections'.format(
        mask_joint_injections.sum()))

    mask_medications = (mask_dmards & mask_steroids & mask_ivig &
                        mask_biologics & mask_joint_injections)

    info('{} patients satisfied medication requirements'.format(
        mask_medications.sum()))

    return pd.DataFrame.from_items(
        [('dmards', mask_dmards), ('steroids', mask_steroids),
         ('ivig', mask_ivig), ('biologics', mask_biologics),
         ('joint_injections', mask_joint_injections),
         ('medications_combined', mask_medications)])


def get_joint_count_masks(df: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains a joint count mask.

    Args:
        df: A table of joint involvements.

    Returns:
        The mask.
    """

    baseline_joint_counts = df.loc[df['visit_id'] == 1].drop(
        'visit_id', axis=1).set_index('subject_id').sum(axis=1)

    mask_joints = baseline_joint_counts > 0

    info('{} patients had joints involved at baseline'.format(mask_joints.sum(
    )))

    return pd.DataFrame.from_items([('joint_count', mask_joints)])


@click.command()
@click.option(
    '--basic-input',
    required=True,
    help='read basic information from Feather file BASIC_INPUT')
@click.option(
    '--medication-input',
    required=True,
    help='read medications from Feather file MEDICATION_INPUT')
@click.option(
    '--joint-injection-input',
    required=True,
    help='read joint injections from Feather file JOINT_INJECTION_INPUT')
@click.option(
    '--joint-input',
    required=True,
    help='read joint involvements from Feather file JOINT_INPUT')
@click.option(
    '--output',
    required=True,
    help='output extracted data to Feather file OUTPUT')
@click.option(
    '--filter-output',
    required=True,
    help='write patient filtering information to CSV file FILTER_OUTPUT')
def main(basic_input, medication_input, joint_injection_input, joint_input,
         output, filter_output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    basic_data, medication_data, joint_injection_data, joint_data = load_data(
        basic_input, medication_input, joint_injection_input, joint_input)

    info('Generating masks')

    masks_basic = get_basic_masks(basic_data)

    masks_medications = get_medication_masks(medication_data,
                                             joint_injection_data)

    mask_joints = get_joint_count_masks(joint_data)

    mask_all = masks_basic['basic_combined'] & masks_medications[
        'medications_combined'] & mask_joints['joint_count']

    masks_all = masks_basic.join(
        masks_medications, how='outer').join(
            mask_joints, how='outer')

    masks_all['all_combined'] = mask_all

    info('{} patients will be retained'.format(mask_all.sum()))

    info('Filtering data')

    data = joint_data.set_index('subject_id').loc[mask_all.index[
        mask_all == True]].reset_index()

    info('Writing outputs')

    data.info()

    feather.write_dataframe(data, output)

    masks_all.to_csv(filter_output)


if __name__ == '__main__':

    main()