"""
Prepares diagnosis and cluster data for oligoarthritis patients.
"""

from click import *
from logging import *

import pandas as pd

MAP = {'Oligoarthritis': 'Oligoarthritis (persistent)'}


@command()
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read clusters from')
@option(
    '--diagnosis-output',
    required=True,
    help='the CSV file to write diagnoses to')
@option(
    '--cluster-output',
    required=True,
    help='the CSV file to write clusters to')
def main(diagnosis_input, cluster_input, diagnosis_output, cluster_output):

    basicConfig(level=DEBUG)

    # Load data.

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col='subject_id')

    debug(f'Result: {diagnoses.shape}')

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0)

    # Filter diagnoses to oligoarthritis.

    info('Filtering diagnoses')

    diagnoses = diagnoses.drop(
        'diagnosis',
        axis=1).rename(columns={'diagnosis_6_months': 'diagnosis'})

    diagnoses = diagnoses.loc[diagnoses['diagnosis'].str.contains(
        r'^Oligoarthritis')]

    debug(f'Result: {diagnoses.shape}')

    # Map undescribed oligoarthritis patients to persistent oligoarthritis.

    info('Mapping unspecified oligoarthritis types to persistent')

    diagnoses['diagnosis'] = [MAP.get(dx, dx) for dx in diagnoses['diagnosis']]

    # Filter cluster assignments.

    info('Filtering cluster assignments')

    clusters = clusters.loc[diagnoses.index]

    debug(f'Result: {clusters.shape}')

    # Write outputs.

    info('Writing outputs')

    diagnoses.to_csv(diagnosis_output)

    clusters.to_csv(cluster_output)


if __name__ == '__main__':
    main()