"""
Generates a patient filter for BBOP from the given data.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--basics-input',
    required=True,
    help='the Feather file to load basic data from')
@option(
    '--medications-input',
    required=True,
    help='the CSV file to load medication data from')
@option(
    '--sites-input',
    required=True,
    help='the Feather file to load site involvement data from')
@option(
    '--output',
    required=True,
    help='the CSV file to output patient filtering information to')
@option(
    '--age-of-symptom-onset-limit',
    type=float,
    help='the maximum age of onset, in years')
@option(
    '--symptom-onset-to-diagnosis-limit',
    type=float,
    help='the maximum duration between symptom onset and diagnosis, in days')
def main(basics_input, medications_input, sites_input, output,
         age_of_symptom_onset_limit, symptom_onset_to_diagnosis_limit):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading basic information')

    df_basics = feather.read_dataframe(basics_input).set_index('subject_id')

    info('Result: {}'.format(df_basics.shape))

    info('Loading medication information')

    df_medications = feather.read_dataframe(medications_input).set_index(
        'subject_id')

    info('Result: {}'.format(df_medications.shape))

    info('Loading site involvements')

    df_sites = feather.read_dataframe(sites_input).set_index('subject_id')

    info('Result: {}'.format(df_sites.shape))

    # Generate filters.

    info('Generating basics filters')

    filter_basics = pd.DataFrame({
        'sex': df_basics['sex'].notnull(),
        'age_symptom_onset_missing': df_basics['age_symptom_onset'].notnull(),
        'age_symptom_onset': df_basics['age_symptom_onset'] > 0,
        'duration_symptom_onset_to_diagnosis_missing':
        df_basics['duration_symptom_onset_to_diagnosis'].notnull(),
        'duration_symptom_onset_to_diagnosis':
        df_basics['duration_symptom_onset_to_diagnosis'] >= 0,
        'diagnosis_missing': df_basics['diagnosis'].notnull(),
        'diagnosis_other': df_basics['diagnosis'] != 'Other'
    })

    if age_of_symptom_onset_limit is not None:

        filter_basics['age_symptom_onset'] &= (
            df_basics['age_symptom_onset'] < age_of_symptom_onset_limit)

    if symptom_onset_to_diagnosis_limit is not None:

        filter_basics['duration_symptom_onset_to_diagnosis'] &= (
            df_basics['duration_symptom_onset_to_diagnosis'] <
            symptom_onset_to_diagnosis_limit)

    info('Generating medications filters')

    filter_medications = pd.DataFrame({
        'medication_joint_injections': df_medications['joint_injection'] == 0,
        'medication_dmards': df_medications['dmard'] == 0,
        'medication_biologics': df_medications['biologic'] == 0,
        'medication_ivig': df_medications['ivig'] == 0,
        'medication_steroids': df_medications['steroid'] == 0
    })

    info('Generating site filters')

    total_sites = df_sites.sum(axis=1)

    filter_sites = pd.DataFrame({'site_count': total_sites > 0})

    # Combine the filters. Additionally, no filter can be missing, i.e., no
    # patient can be missing information for a particular domain.

    filter_all = filter_basics.join(filter_medications).join(filter_sites)

    filter_all['mask'] = filter_all.all(axis=1) & (
        filter_all.isnull().sum(axis=1) < 1)

    # Write the output.

    info('Writing output')

    filter_all.to_csv(output)


if __name__ == '__main__':
    main()