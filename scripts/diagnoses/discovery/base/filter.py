"""
Filters diagnoses to those of the cohort.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to load diagnoses from')
@option(
    '--filter-input',
    required=True,
    help='the CSV file to load patient inclusion information from')
@option(
    '--output',
    required=True,
    help='the CSV file to write filtered diagnoses to')
def main(diagnosis_input, filter_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col=0)

    info('Result: {}'.format(diagnoses.shape))

    info('Loading filter')

    patient_filter = pd.read_csv(filter_input, index_col=0)

    info('Result: {}'.format(patient_filter.shape))

    info('Filtering diagnoses')

    diagnoses = diagnoses.loc[patient_filter.index[patient_filter[
        'all_combined'] == True]]

    info('Writing output')

    diagnoses.to_csv(output)


if __name__ == '__main__':
    main()