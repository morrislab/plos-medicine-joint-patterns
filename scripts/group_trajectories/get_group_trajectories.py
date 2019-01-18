"""
Obtains group trajectories for patients.
"""

import pandas as pd
import string
import tqdm

from click import *
from logging import *


def _get_cluster(df):
    """
    Obtains a patient group assignment from a table of scores for a given
    patient.

    :param pd.DataFrame df

    :rtype: int
    """

    if df['score'].max() == 0.:

        return 0

    return df.set_index('factor')['score'].argmax()


def get_clusters(df):
    """
    Obtains patient groups from the given table.

    :param pd.DataFrame df

    :rtype: pd.DataFrame
    """

    g = df.groupby(['subject_id', 'visit_id'])

    tqdm.tqdm.pandas()

    clusters = g.progress_apply(_get_cluster)

    clusters.name = 'classification_int'

    clusters = clusters.reset_index()

    clusters['classification'] = pd.Series(['0'] + list(
        string.ascii_uppercase))[clusters['classification_int']].values

    return clusters.drop('classification_int', axis=1)


@command()
@option(
    '--baseline-cluster-input',
    required=True,
    help='the CSV file to read baseline cluster assignments from')
@option(
    '--score-input', required=True, help='the CSV file to read scores from')
@option(
    '--output',
    required=True,
    help='the CSV file to write patient group trajectories to')
def main(baseline_cluster_input, score_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading baseline cluster assignments')

    baseline_clusters = pd.read_csv(baseline_cluster_input)

    info('Result: {}'.format(baseline_clusters.shape))

    info('Loading scores')

    scores = pd.read_csv(score_input)

    scores.rename(columns={scores.columns[0]: 'subject_id'}, inplace=True)

    info('Result: {}'.format(scores.shape))

    info('Filtering scores')

    scores = scores.loc[scores['visit_id'] > 1]

    info('Calculating patient groups')

    clusters = get_clusters(scores)

    info('Concatenating patient groups')

    baseline_clusters['visit_id'] = 1

    clusters = pd.concat([baseline_clusters, clusters])

    info('Writing output')

    clusters.to_csv(output, index=False)


if __name__ == '__main__':
    main()