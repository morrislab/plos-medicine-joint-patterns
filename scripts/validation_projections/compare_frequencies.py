"""
Compares frequencies between the validation and discovery cohorts.

For each patient group, the Euclidean distance is used.
"""

import numpy as np
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--validation-input',
    required=True,
    help='the CSV file to read validation frequencies from')
@option(
    '--discovery-input',
    required=True,
    help='the CSV file to read discovery frequencies from')
@option('--output', required=True, help='the CSV file to write scores to')
def main(validation_input: str, discovery_input: str, output: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading validation data')

    validation_data = pd.read_csv(
        validation_input, index_col=['classification', 'site'])

    info('Result: {}'.format(validation_data.shape))

    info('Loading discovery data')

    discovery_data = pd.read_csv(
        discovery_input, index_col=['classification', 'site'])

    info('Result: {}'.format(discovery_data.shape))

    # Calculate distances between frequencies.

    differences = validation_data - discovery_data

    distances = np.sqrt((differences
                         **2).groupby(['classification'])['frequency'].sum())

    distances.name = 'distance'

    # Write the output.

    info('Writing output')

    distances.to_frame().to_csv(output)


if __name__ == '__main__':
    main()
