"""
Extracts patient basics from BBOP.
"""

import collections
import feather
import pandas as pd

from click import *
from logging import *

COLUMNS = collections.OrderedDict(
    [('PatientID', 'subject_id'), ('SEX', 'sex'), ('BIRTH_DATE', 'date_birth'),
     ('DIAG_DATE', 'date_diagnosis'), ('ENROLLMENT_DX', 'diagnosis'),
     ('JIA_ONSET_SYMP_DATE', 'date_symptom_onset'),
     ('@1ST_CLINIC_VISIT_DATE', 'date_first_visit')])

SEXES = {1: 'M', 2: 'F'}

DIAGNOSES = {
    23: 'Undifferentiated',
    24: 'Enthesitis-related arthritis',
    25: 'Oligoarthritis',
    26: 'Psoriatic',
    27: 'RF-negative polyarthritis',
    28: 'RF-positive polyarthritis',
    31: 'Systemic'
}


@command()
@option('--input', required=True, help='the CSV file to load input data from')
@option(
    '--output',
    required=True,
    help='the Feather file to output extracted data to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(input, encoding='ISO-8859-1')

    info('Result: {}'.format(data.shape))

    # Filter the data by visit.

    info('Filtering to baseline visit and BBOP cohort 1')

    data = data.query('VisitNumber == 1 and BBOPcohort == 1')

    # Extract the data.

    info('Extracting data')

    data = data[list(COLUMNS.keys())].copy()

    data.rename(columns=COLUMNS, inplace=True)

    # Convert subject IDs.

    info('Converting subject IDs')

    data['subject_id'] = data['subject_id'].str.replace(',', '').astype(int)

    # Convert sexes.

    info('Converting sexes')

    data['sex'] = data['sex'].apply(SEXES.__getitem__)

    # Convert diagnoses.

    info('Converting diagnoses')

    data['diagnosis'] = data['diagnosis'].apply(DIAGNOSES.__getitem__).astype(
        'category')

    # Convert dates.

    info('Converting dates')

    for j in [
            'date_birth', 'date_diagnosis', 'date_symptom_onset',
            'date_first_visit'
    ]:

        data[j] = pd.to_datetime(data[j])

    # Calculate durations.

    info('Calculating durations')

    days = pd.to_timedelta(1, 'D')

    data['age_symptom_onset'] = (
        data['date_symptom_onset'] - data['date_birth']) / days

    data['age_diagnosis'] = (
        data['date_diagnosis'] - data['date_birth']) / days

    data['duration_symptom_onset_to_diagnosis'] = (
        data['date_diagnosis'] - data['date_symptom_onset']) / days

    data.drop(
        ['date_birth', 'date_symptom_onset', 'date_first_visit'],
        axis=1,
        inplace=True)

    # Write the output.

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':
    main()