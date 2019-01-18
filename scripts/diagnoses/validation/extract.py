"""
Extracts diagnoses for the validation cohort.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to load site involvement data from')
@option(
    '--demographics-input',
    required=True,
    help='the Feather file to load demographics from')
@option('--output', required=True, help='the CSV file to output diagnoses to')
def main(data_input, demographics_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input)

    data.info()

    info('Loading demographics')

    demographics = feather.read_dataframe(demographics_input)

    demographics.info()

    # Filter and select the demographics.

    info('Filtering and selecting demographic data')

    subject_ids = pd.Index(data['subject_id'])

    diagnoses = demographics.set_index('subject_id')['diagnosis']

    diagnoses = diagnoses.loc[subject_ids]

    # Write the output.

    info('Writing output')

    diagnoses.to_frame().to_csv(output)


if __name__ == '__main__':
    main()