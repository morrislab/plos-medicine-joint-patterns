"""
Extracts and formats diagnoses.
"""

import click
import feather

from logging import *


@click.command()
@click.option(
    '--input', required=True, help='read input data from Feather file INPUT')
@click.option(
    '--output', required=True, help='output diagnoses to CSV file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = feather.read_dataframe(input)

    data.info()

    info('Extracting and formatting diagnoses')

    data = data[['subject_id', 'diagnosis_6_months']]

    data['diagnosis'] = data['diagnosis_6_months'].dropna().str.upper().apply({
        'ENTHE': 'Enthesitis-related arthritis',
        'IBD': 'Enthesitis-related arthritis',
        'OLIGO': 'Oligoarthritis',
        'O_EXT': 'Oligoarthritis',
        'P_ERA': 'Enthesitis-related arthritis',
        'P_NEG': 'RF-negative polyarthritis',
        'P_POS': 'RF-positive polyarthritis',
        'PSORI': 'Psoriatic',
        'SYS': 'Systemic',
        'UNCLA': 'Undifferentiated',
        'WITHDRAWN': 'Withdrawn'
    }.__getitem__)

    data['diagnosis_6_months'] = data['diagnosis_6_months'].dropna().str.upper(
    ).apply({
        'ENTHE': 'Enthesitis-related arthritis',
        'IBD': 'Enthesitis-related arthritis',
        'OLIGO': 'Oligoarthritis (persistent)',
        'O_EXT': 'Oligoarthritis (extended)',
        'P_ERA': 'Enthesitis-related arthritis',
        'P_NEG': 'RF-negative polyarthritis',
        'P_POS': 'RF-positive polyarthritis',
        'PSORI': 'Psoriatic',
        'SYS': 'Systemic',
        'UNCLA': 'Undifferentiated',
        'WITHDRAWN': 'Withdrawn'
    }.__getitem__)

    info('Writing data')

    data.info()

    data.to_csv(output, index=False)


if __name__ == '__main__':

    main()