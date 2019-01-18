"""
Extracts patient basics from the validation cohort.
"""

import collections
import feather
import numpy as np
import pandas as pd

from click import *
from logging import *

COLUMNS = collections.OrderedDict(
    [('ID', 'subject_id'), ('SEX', 'sex'), (' DOB', 'date_birth'),
     ('\nDiagnosis date', 'date_diagnosis'),
     ('\nPrimary Diagnosis', 'diagnosis_primary'),
     ('DSOA', 'date_symptom_onset'), ('DOFV', 'date_first_visit'),
     ('\nNEWEST Diagnosis', 'diagnosis_newest'),
     ('Diagnosis by JIA Criteria ', 'diagnosis_jia')])


@command()
@option(
    '--input',
    required=True,
    metavar='INPUT',
    help='load input data from Excel file INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output extracted data to Feather file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_excel(input)

    data.info()

    # Extract data.

    info('Extracting data')

    df = data[list(COLUMNS.keys())].copy()

    df.rename(columns=COLUMNS, inplace=True)

    for j in [
            'date_birth', 'date_diagnosis', 'date_symptom_onset',
            'date_first_visit'
    ]:

        df[j] = pd.to_datetime(df[j])

    # Fix the sexes.

    info('Fixing sexes')

    df['sex'] = df['sex'].str[0]

    df['sex'] = df['sex'].astype('category')

    # Calculate dates.

    info('Calculating durations')

    days = pd.to_timedelta(1, 'D')

    df['age_symptom_onset'] = (
        df['date_symptom_onset'] - df['date_birth']) / days

    df['age_diagnosis'] = (df['date_diagnosis'] - df['date_birth']) / days

    df['duration_symptom_onset_to_diagnosis'] = (
        df['date_diagnosis'] - df['date_symptom_onset']) / days

    df.drop(
        ['date_birth', 'date_symptom_onset', 'date_first_visit'],
        axis=1,
        inplace=True)

    # Fix the diagnoses.

    info('Fixing diagnoses')

    df['diagnosis'] = np.where(
        pd.notnull(df['diagnosis_newest']), df['diagnosis_newest'],
        df['diagnosis_primary'])

    df['diagnosis'] = np.where(
        pd.notnull(df['diagnosis_jia']), df['diagnosis_jia'], df['diagnosis'])

    df['diagnosis'] = df['diagnosis'].str.strip('*')

    df['diagnosis'] = df['diagnosis'].astype('category')

    df.drop(
        ['diagnosis_primary', 'diagnosis_newest', 'diagnosis_jia'],
        axis=1,
        inplace=True)

    # Write the output.

    info('Writing output')

    df.info()

    feather.write_dataframe(df, output)


if __name__ == '__main__':
    main()