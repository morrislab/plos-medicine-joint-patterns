"""
For each patient, calculates their reconstruction based on cluster centroids.
"""

from click import *
from logging import *

import pandas as pd


@command()
@option(
    '--data-input', required=True, help='the CSV file to read input data from')
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--output',
    required=True,
    help='the CSV file to write the reconstructions to')
def main(data_input, diagnosis_input, output):

    basicConfig(level=DEBUG)

    # Load the data.

    info('Loading data...')

    info('Loading data')

    X = pd.read_csv(data_input, index_col=0)

    debug(f'Result: {X.shape}')

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col=0)[['diagnosis']]

    debug(f'Result: {diagnoses.shape}')

    # Calculate centroids.

    info('Calculating centroids')

    centroids = diagnoses.join(X).groupby('diagnosis').mean()

    # Generate reconstructions.

    info('Generating reconstructions')

    reconstructions = diagnoses.reset_index().set_index('diagnosis').join(
        centroids).reset_index().set_index('subject_id').drop(
            'diagnosis', axis=1)

    # Write the output.

    info('Writing output')

    reconstructions.to_csv(output)


if __name__ == '__main__':
    main()