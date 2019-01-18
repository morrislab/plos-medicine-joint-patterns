"""
Merges diagnoses together, with priority to validation diagnoses.
"""

from click import *
from logging import *

import pandas as pd

ORIGINAL_MAP = {
    'Systemic': 'Systemic arthritis',
    'Undifferentiated': 'Undifferentiated arthritis',
    'Psoriatic': 'Psoriatic arthritis'
}


@command()
@option(
    '--original-input',
    required=True,
    help='the CSV file to load original diagnoses from')
@option(
    '--validated-input',
    required=True,
    help='the CSV file to load validated diagnoses from')
@option('--output', required=True, help='the CSV file to write output to')
def main(original_input, validated_input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info('Loading original diagnoses')

    X_original = pd.read_csv(original_input, index_col='subject_id')

    debug(f'Result: {X_original.shape}')

    info('Loading validated diagnoses')

    X_validated = pd.read_csv(validated_input, index_col='subject_id')

    debug(f'Result: {X_validated.shape}')

    X_validated_baseline = X_validated.query('visit_id == 1').drop(
        'visit_id', axis=1)

    X_validated_6_months = X_validated.query('visit_id == 2').drop(
        'visit_id', axis=1)

    # Map original diagnoses.

    info('Mapping original diagnoses')

    X_original['diagnosis'] = [
        ORIGINAL_MAP.get(dx, dx) for dx in X_original['diagnosis']
    ]

    X_original['diagnosis_6_months'] = [
        ORIGINAL_MAP.get(dx, dx) for dx in X_original['diagnosis_6_months']
    ]

    # Determine from where diagnoses should come from at each time point.

    sources = {
        'baseline': {
            'validated':
            X_validated_baseline.index.intersection(X_original.index),
            'original':
            X_original.index.difference(X_validated_baseline.index)
        },
        '6_months': {
            'validated':
            X_validated_6_months.index.intersection(X_original.index),
            'original':
            X_original.index.difference(X_validated_6_months.index)
        }
    }

    debug(
        f'Baseline: {sources["baseline"]["original"].size} original diagnoses; '
        f'{sources["baseline"]["validated"].size} validated diagnoses')

    debug(
        f'6 months: {sources["6_months"]["original"].size} original diagnoses; '
        f'{sources["6_months"]["validated"].size} validated diagnoses')

    # Merge the diagnoses.

    info('Merging diagnoses')

    baseline_diagnoses = pd.concat([
        X_validated_baseline.loc[sources['baseline']['validated'],
                                 'diagnosis'],
        X_original.loc[sources['baseline']['original'], 'diagnosis']
    ])

    six_month_diagnoses = pd.concat([
        X_validated_6_months.loc[sources['6_months']['validated'],
                                 'extended_diagnosis'],
        X_original.loc[sources['6_months']['original'], 'diagnosis_6_months']
    ])

    Y = pd.DataFrame({
        'diagnosis': baseline_diagnoses,
        'diagnosis_6_months': six_month_diagnoses
    })

    debug(f'Result: {Y.shape}')

    # Write output.

    info('Writing output')

    Y.to_csv(output)


if __name__ == '__main__':
    main()