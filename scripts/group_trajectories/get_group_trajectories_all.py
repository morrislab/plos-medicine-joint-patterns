"""
Obtains group trajectories for all patients in REACCH OUT.
"""

import click
import pandas as pd
import string
import tqdm

from logging import *


def load_data(handle):
    """
    Loads patient factor scores from the given handle.

    :param str handle

    :rtype: pd.DataFrame
    """

    info('Loading joint involvement data')

    result = pd.read_csv(handle)

    result.rename(columns={result.columns[0]: 'subject_id'}, inplace=True)

    info('Loaded a table with shape {}'.format(result.shape))

    return result


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

    info('Calculating patient groups')

    g = df.groupby(['subject_id', 'visit_id'])

    tqdm.tqdm.pandas()

    clusters = g.progress_apply(_get_cluster)

    clusters.name = 'classification_int'

    clusters = clusters.reset_index()

    clusters['classification'] = pd.Series(['0'] + list(
        string.ascii_uppercase))[clusters['classification_int']].values

    return clusters.drop('classification_int', axis=1)


def write_output(df, filename):
    """
    Writes the given data frame to the given file.

    :param pd.DataFrame df

    :param str filename
    """

    info('Writing output')

    df.to_csv(filename, index=False)


@click.command()
@click.option(
    '--score-input',
    type=click.File('rU'),
    required=True,
    help='read scores from CSV file SCORE_INPUT')
@click.option(
    '--output',
    required=True,
    help='write patient group trajectories to CSV file OUTPUT')
def main(score_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    scores = load_data(score_input)

    clusters = get_clusters(scores)

    write_output(clusters, output)

    info('Done')


if __name__ == '__main__':
    main()