"""
Calculates an averaged co-occurrence matrix from co-occurrence matrices for
individual patient groups.

The result for each pair of joints is a weighted mean, where the weights are
the number of patients per patient group.
"""

import click
import feather
import functools as ft
import pandas as pd
import tqdm

from logging import *


def load_data(co_occurrence_path, cluster_handle):
    """
    Reads co-occurrence data from the given filename and cluster assignments
    from the given handle.

    :param str co_occurrence_path

    :param io.file cluster_handle

    :rtype Tuple[pd.DataFrame, pd.Series[int]]
    """

    info('Loading co-occurrences from {}'.format(co_occurrence_path))

    co_occurrences = feather.read_dataframe(co_occurrence_path)

    info('Loaded a table with shape {}'.format(co_occurrences.shape))

    info('Loading patient groups from {}'.format(cluster_handle.name))

    clusters = pd.read_csv(cluster_handle, index_col=0, squeeze=True)

    info('Loaded {} entries'.format(clusters.size))

    return co_occurrences, clusters


def _get_average_co_occurrence(df, weights, summed_weights):
    """
    Calculates the weighted mean of co-occurrence for a given pair of joints.

    :param pd.DataFrame df

    :param pd.Series[int] weights

    :param int summed_weights

    :rtype pd.Series[float]
    """

    df = df.set_index('classification')

    return pd.Series(
        {
            'frequency': df['frequency'].sum(),
            'probability':
            (df['probability'] * weights).sum() / summed_weights,
            'conditional_probability':
            (df['conditional_probability'] * weights).sum() / summed_weights,
            'jaccard': (df['jaccard'] * weights).sum() / summed_weights
        },
        dtype=object)


def average_co_occurrences(df_co_occurrences, clusters):
    """
    Calculates weighted means of co-occurrences and conditional co-occurrences.

    :param pd.df_co_occurrences df_co_occurrences

    :param pd.Series[int] clusters

    :rtype: pd.DataFrame
    """

    info('Averaging co-occurrences')

    weights = clusters.value_counts()

    weights.name = 'weights'

    summed_weights = weights.sum()

    g = df_co_occurrences.groupby(['reference_joint', 'co_occurring_joint'])

    tqdm.tqdm.pandas()

    result = g.progress_apply(
        ft.partial(
            _get_average_co_occurrence,
            weights=weights,
            summed_weights=summed_weights)).reset_index()

    for j in ['reference_joint', 'co_occurring_joint']:

        result[j] = result[j].astype('category')

    result['classification'] = 0

    return result


def write_output(co_occurrences, path):
    """
    Writes the given co-occurrences to the given path.

    :param pd.DataFrame co_occurrences

    :param str path
    """

    info('Writing output')

    feather.write_dataframe(co_occurrences, path)


@click.command()
@click.option(
    '--co-occurrence-input',
    required=True,
    help='read co-occurrences from Feather file CO_OCCURRENCE_INPUT')
@click.option(
    '--cluster-input',
    type=click.File('rU'),
    help='read patient group assignments from CSV file CLUSTER_INPUT')
@click.option(
    '--output',
    required=True,
    help='write average co-occurrences to Feather file OUTPUT')
def main(co_occurrence_input, cluster_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    co_occurrences, clusters = load_data(co_occurrence_input, cluster_input)

    mean_co_occurrences = average_co_occurrences(co_occurrences, clusters)

    write_output(mean_co_occurrences, output)


if __name__ == '__main__':
    main()