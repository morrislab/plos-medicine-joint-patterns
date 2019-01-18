"""
Obtains a filter for patients.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--basics-input',
    required=True,
    metavar='BASICS-INPUT',
    help='load basics data from Feather file BASICS-INPUT')
@option(
    '--medications-input',
    required=True,
    metavar='MEDICATIONS-INPUT',
    help='load medications data from Feather file MEDICATIONS-INPUT')
@option(
    '--sites-input',
    required=True,
    metavar='SITES-INPUT',
    help='load site data from Feather file SITES-INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output the filter to CSV file OUTPUT')
@option(
    '--age-of-symptom-onset',
    type=int,
    metavar='AGE',
    help='restrict ages of symptom onset to less than AGE days')
@option(
    '--symptom-onset-to-diagnosis',
    type=int,
    metavar='TIME',
    help='restrict symptom onsets to diagnosis to less than TIME days')
def main(basics_input, medications_input, sites_input, output,
         age_of_symptom_onset, symptom_onset_to_diagnosis):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading basics data')

    df_basics = feather.read_dataframe(basics_input).set_index('subject_id')

    df_basics.info()

    info('Loading medications data')

    df_medications = feather.read_dataframe(medications_input).set_index(
        'subject_id')

    df_medications.info()

    info('Loading site data')

    df_sites = feather.read_dataframe(sites_input).set_index('subject_id')

    df_sites.info()

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

    if age_of_symptom_onset is not None:

        filter_basics['age_symptom_onset'] &= (
            df_basics['age_symptom_onset'] < age_of_symptom_onset)

    if symptom_onset_to_diagnosis is not None:

        filter_basics['duration_symptom_onset_to_diagnosis'] &= (
            df_basics['duration_symptom_onset_to_diagnosis'] <
            symptom_onset_to_diagnosis)

    info('Generating medications filters')

    filter_medications = pd.DataFrame({
        'medication_joint_injections_missing':
        df_medications['medication_joint_injections'].notnull(),
        'medication_joint_injections':
        df_medications['medication_joint_injections'] == 0,
        'medication_dmards_missing':
        df_medications['medication_dmards'].notnull(),
        'medication_dmards': df_medications['medication_dmards'] == 0,
        'medication_biologics_missing':
        df_medications['medication_biologics'].notnull(),
        'medication_biologics': df_medications['medication_biologics'] == 0,
        'medication_steroids_missing':
        df_medications['medication_steroids'].notnull(),
        'medication_steroids': df_medications['medication_steroids'] == 0
    })

    info('Generating site filters')

    total_sites = df_sites.sum(axis=1)

    filter_sites = pd.DataFrame({'mask_site_count': total_sites > 0})

    # Combine the filters. Additionally, no filter can be missing, i.e., no
    # patient can be missing information for a particular domain.

    filter_all = filter_basics.join(filter_medications).join(filter_sites)

    filter_all['mask'] = filter_all.all(axis=1) & (
        filter_all.isnull().sum(axis=1) < 1)

    # Output the resulting data.

    info('Writing data')

    filter_all.info()

    filter_all.to_csv(output)


if __name__ == '__main__':
    main()