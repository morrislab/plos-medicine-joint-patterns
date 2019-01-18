"""
Extracts basic patient information.
"""

import click
import feather
import pandas as pd

from logging import *


@click.command()
@click.option(
    '--input', required=True, help='read input data from XLS file INPUT')
@click.option(
    '--output',
    required=True,
    help='output extracted data to Feather file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = pd.read_excel(input)

    info('Converting dates')

    for j in ['DOB', 'ONSET_DATE_15TH', 'DIAGNOSIS_DATE']:

        data[j] = pd.to_datetime(data[j])

    info('Calculating age at diagnosis and time to diagnosis')

    data['diagnosis_age'] = (
        data['DIAGNOSIS_DATE'] - data['DOB']) / pd.to_timedelta(1, 'D')

    data['symptom_onset_to_diagnosis'] = (
        data['DIAGNOSIS_DATE'] - data['ONSET_DATE_15TH']) / pd.to_timedelta(
            1, 'D')

    info('Selecting data')

    data = data[[
        'SUBJECT_ID', 'SEX', '6MDX', 'Withdrawn', 'onset_age', 'diagnosis_age',
        'symptom_onset_to_diagnosis'
    ]]

    data.columns = [
        'subject_id', 'sex', 'diagnosis_6_months', 'withdrawn',
        'symptom_onset_age', 'diagnosis_age_days',
        'symptom_onset_to_diagnosis_days'
    ]

    info('Reformatting data')

    data['withdrawn'] = data['withdrawn'].fillna(0).astype(bool)

    for j in ['sex', 'diagnosis_6_months']:

        data[j] = data[j].astype('category')

    data.info()

    info('Writing data')

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()