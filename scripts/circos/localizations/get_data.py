"""
Obtains Circos input data for the given localization.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--score-input', required=True, help='the CSV file to read scores from')
@option(
    '--localization-input',
    required=True,
    help='the CSV file to read localizations from')
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--localization',
    required=True,
    help='the localization to obtain data for')
@option(
    '--score-output', required=True, help='the CSV file to output scores to')
@option(
    '--cluster-output',
    required=True,
    help='the CSV file to output clusters to')
@option(
    '--diagnosis-output',
    required=True,
    help='the CSV file to output diagnoses to')
def main(score_input: str, localization_input: str, diagnosis_input: str,
         localization: str, score_output: str, cluster_output: str,
         diagnosis_output: str):

    basicConfig(level=DEBUG)

    info('Loading scores')

    scores = pd.read_csv(score_input, index_col=0)

    debug(f'Result: {scores.shape}')

    info('Loading localizations')

    localizations = pd.read_csv(
        localization_input, index_col=0).drop(
            'threshold', axis=1)

    debug(f'Result: {localizations.shape}')

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col=0)[['diagnosis']]

    debug(f'Result: {diagnoses.shape}')

    info('Filtering localizations')

    localizations = localizations.query('localization == @localization').drop(
        'localization', axis=1)

    if localizations.shape[0] < 1:

        raise Exception(f'classification {localization!r} has no patients')

    debug(f'Result: {localizations.shape}')

    info('Filtering scores')

    scores = scores.loc[localizations.index]

    debug(f'Result: {scores.shape}')

    info('Filtering diagnoses')

    diagnoses = diagnoses.loc[localizations.index]

    debug(f'Result: {diagnoses.shape}')

    info('Reducing to patient intersection')

    patient_intersect = scores.index.intersection(
        localizations.index).intersection(diagnoses.index)

    if patient_intersect.shape[0] < 1:

        raise Exception('no patients in intersection')

    scores = scores.loc[patient_intersect]

    localizations = localizations.loc[patient_intersect]

    diagnoses = diagnoses.loc[patient_intersect]

    info('Writing output')

    debug(f'Writing {score_output}')

    scores.to_csv(score_output)

    debug(f'Writing {cluster_output}')

    localizations.to_csv(cluster_output)

    debug(f'Writing {diagnosis_output}')

    diagnoses.to_csv(diagnosis_output)


if __name__ == '__main__':
    main()
