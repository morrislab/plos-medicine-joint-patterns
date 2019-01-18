"""
Maps diagnoses.
"""

import pandas as pd
import yaml

from click import *
from logging import *


@command()
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--mapping-input',
    required=True,
    help='the YAML file to read mappings from')
@option('--output', required=True, help='the CSV file to write output to')
def main(diagnosis_input, mapping_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the diagnoses.

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input)

    info('Result: {}'.format(diagnoses.shape))

    # Load the mappings.

    info('Loading mappings')

    with open(mapping_input, 'r') as h:

        mapping = yaml.load(h)

    info('Loaded {} entries'.format(len(mapping)))

    # Map diagnoses.

    info('Mapping diagnoses')

    diagnoses['diagnosis'] = diagnoses['diagnosis'].apply(mapping.__getitem__)

    # Write the output.

    info('Writing output')

    diagnoses.to_csv(output, index=False)


if __name__ == '__main__':
    main()