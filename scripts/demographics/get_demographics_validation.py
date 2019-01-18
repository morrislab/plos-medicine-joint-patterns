"""
Extracts demographics for the validation cohort.
"""

import click
import feather
import pandas as pd

from logging import *


@click.command()
@click.option(
    '--basics-input',
    required=True,
    help='read basics data from Feather file BASICS_INPUT')
@click.option(
    '--data-input',
    required=True,
    type=click.File('rU'),
    help='read site data from DATA_INPUT')
@click.option('--output', required=True, help='output a report to OUTPUT')
def main(basics_input, data_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading basics data from {}'.format(basics_input))

    basics_data = feather.read_dataframe(basics_input).set_index('subject_id')

    basics_data.info()

    info('Reading site data from {}'.format(data_input.name))

    data = pd.read_csv(data_input, index_col=0)

    data.info()

    info('Filtering demographics')

    basics_data = basics_data.loc[data.index]

    info('Transforming demographics')

    for j in ['age_diagnosis', 'age_symptom_onset']:

        basics_data[j] = basics_data[j] / 365.25

    info('Writing report to {}'.format(output))

    with open(output, 'w') as handle:

        handle.write(basics_data.describe().to_string())

        handle.write('\n\n')

        handle.write(basics_data['sex'].value_counts().to_string())

        handle.write('\n\n')

        handle.write(basics_data['diagnosis'].value_counts().to_string())

        handle.write('\n\n')

        handle.write('Dates of diagnosis:\n')

        handle.write('Min: {}\n'.format(basics_data['date_diagnosis'].min()))

        handle.write('Max: {}\n'.format(basics_data['date_diagnosis'].max()))


if __name__ == '__main__':

    main()