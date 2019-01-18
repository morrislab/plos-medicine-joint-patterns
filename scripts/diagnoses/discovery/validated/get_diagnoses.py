"""
Obtains validated diagnoses.
"""

from click import *
from logging import *

import janitor as jn
import numpy as np
import pandas as pd

VISITS = {'Baseline': 1, '6 month Follow-Up': 2}

DIAGNOSES = {
    'ENTHE': 'Enthesitis-related arthritis',
    'IBD': 'Enthesitis-related arthritis',
    'OLIGO': 'Oligoarthritis',
    'O_EXT': 'Oligoarthritis',
    'O_PER': 'Oligoarthritis',
    'PSORI': 'Psoriatic arthritis',
    'PSORi': 'Psoriatic arthritis',
    'P_ERA': 'Enthesitis-related arthritis',
    'P_NEG': 'RF-negative polyarthritis',
    'P_POS': 'RF-positive polyarthritis',
    'SYS': 'Systemic arthritis',
    'UNCLA': 'Undifferentiated arthritis'
}

EXTENDED_DIAGNOSES = {
    'ENTHE': 'Enthesitis-related arthritis',
    'IBD': 'Enthesitis-related arthritis',
    'OLIGO': 'Oligoarthritis',
    'O_EXT': 'Oligoarthritis (extended)',
    'O_PER': 'Oligoarthritis (persistent)',
    'PSORI': 'Psoriatic arthritis',
    'PSORi': 'Psoriatic arthritis',
    'P_ERA': 'Enthesitis-related arthritis',
    'P_NEG': 'RF-negative polyarthritis',
    'P_POS': 'RF-positive polyarthritis',
    'SYS': 'Systemic arthritis',
    'UNCLA': 'Undifferentiated arthritis'
}


@command()
@option(
    '--input', required=True, help='the Excel file to read input data from')
@option('--output', required=True, help='the CSV file to output diagnoses to')
def main(input, output):

    basicConfig(level=DEBUG)

    # Load data.

    info('Loading data')

    X = pd.read_excel(input)

    debug(f'Result: {X.shape}')

    # Rename columns.

    info('Renaming columns')

    X = jn.clean_names(X, strip_underscores='both')

    # Remove withdrawn patients.

    info('Removing withdrawn patients')

    X = X.query('diagnosis_status != "WITH"')

    debug(f'Result: {X.shape}')

    # Drop null visits.

    info('Dropping null visits')

    X = X.loc[X['visit_name'].notnull()]

    debug(f'Result: {X.shape}')

    # Change subject IDs to integers.

    info('Changing subject IDs to integers')

    X['subject_id'] = X['subject_id'].astype(int)

    # Map visits to visit IDs.

    info('Mapping visit names to IDs')

    X['visit_id'] = X['visit_name'].apply(VISITS.__getitem__)

    debug(f'Result: {X.shape}')

    # Calculate diagnoses.

    info('Calculating diagnoses')

    X = X.set_index(['subject_id', 'visit_id'])

    raw_diagnoses = pd.Series(
        np.where(X['diagnosis_status'] == 'COR', X['diagnosis'],
                 X['cor_diagnosis']),
        index=X.index,
        name='diagnosis')

    extended_diagnoses = pd.Series(
        raw_diagnoses.apply(EXTENDED_DIAGNOSES.__getitem__),
        name='extended_diagnosis')

    base_diagnoses = pd.Series(
        raw_diagnoses.map(DIAGNOSES.__getitem__), name='diagnosis')

    diagnoses = base_diagnoses.to_frame().join(extended_diagnoses.to_frame())

    debug(f'Result: {diagnoses.shape}')

    # Write output.

    info('Writing output')

    diagnoses.to_csv(output)


if __name__ == '__main__':
    main()