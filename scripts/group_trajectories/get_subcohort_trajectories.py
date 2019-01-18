"""
Obtains subcohort trajectories.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to load patient groups from')
@option(
    '--subcohort-input',
    required=True,
    help='the CSV file to load subcohort assignments from')
@option(
    '--visit',
    type=int,
    required=True,
    multiple=True,
    help='the visits to extract subcohort information from (multiple allowed)')
@option(
    '--output', required=True, help='the CSV file to write trajectories to')
def main(cluster_input, subcohort_input, visit, output):

    if 1 in visit:

        raise BadOptionUsage('bad --visit: {!r}'.format(1))

    basicConfig(
        level=INFO,
        handlers=[StreamHandler(), FileHandler('{}.log'.format(output))])

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input)

    info('Result: {}'.format(clusters.shape))

    info('Loading subcohorts')

    subcohorts = pd.read_csv(subcohort_input)

    info('Result: {}'.format(subcohorts.shape))

    info('Filtering subcohort information')

    subcohorts = subcohorts.loc[subcohorts['visit_id'].isin(
        visit) & subcohorts['subject_id'].isin(clusters['subject_id'])]

    subcohorts.rename(columns={'subcohort': 'classification'}, inplace=True)

    info('Concatenating cluster information')

    clusters['visit_id'] = 1

    concatenated = pd.concat([clusters, subcohorts])

    info('Writing output')

    concatenated.to_csv(output, index=False)


if __name__ == '__main__':
    main()