"""
Calculates conditional joint co-occurrence data.
"""

import click
import feather
import itertools as it
import joblib as jl
import numpy as np
import pandas as pd
import tqdm

from logging import *


def load_data(original_input_handle, cluster_input_handle):
    """
    Loads the original data and the cluster assignments from the given handles.

    :param io.file original_input_handle

    :param io.file cluster_input_handle

    :rtype: Tuple[pd.DataFrame, pd.Series[int]]
    """

    info('Loading original data from {}'.format(original_input_handle.name))

    original_data = pd.read_csv(original_input_handle, index_col=0)

    info('Loaded a table with shape {}'.format(original_data.shape))

    clusters = None

    if cluster_input_handle is not None:

        info('Loading cluster assignments from {}'.format(
            cluster_input_handle.name))

        clusters = pd.read_csv(cluster_input_handle, index_col=0, squeeze=True)

        info('Loaded {} entries'.format(clusters.size))

    return original_data, clusters


def split_data(df_data, clusters):
    """
    Splits the given data by the given cluster assignments.

    :param pd.DataFrame df_data

    :param pd.Series[int] clusters

    :rtype: Dict[int, pd.DataFrame]
    """

    if clusters is None:

        return {0: df_data}

    return {
        k: df_data.loc[clusters.index[clusters == k]]
        for k in clusters.unique()
    }


def _get_co_occurrence(k, i, xi, j, xj):
    """
    Calculates the raw and conditional joint co-occurrence frequencies for a
    given cluster, reference joint, values for the reference joint, co-
    occurring joint, and values for the co-occurring joint.

    :param int k

    :param str i

    :param pd.Series[int] xi

    :param str j

    :param pd.Series[int] xj

    :rtype: pd.DataFrame
    """

    frequency = (xi & xj).sum()

    reference_count = xi.sum()

    probability = frequency / xi.size

    conditional_probability = (frequency / reference_count
                               if reference_count > 0 else np.nan)

    jaccard_denominator = (xi | xj).sum()

    jaccard = (frequency / jaccard_denominator
               if jaccard_denominator > 0 else np.nan)

    return pd.DataFrame(
        {
            'classification': k,
            'reference_site': i,
            'co_occurring_site': j,
            'frequency': frequency,
            'probability': probability,
            'conditional_probability': conditional_probability,
            'jaccard': jaccard
        },
        index=[0])


def get_co_occurrences(dfs, variables, cores=None):
    """
    Obtains raw and conditional joint co-occurrence frequencies from the given
    data.

    :param Dict[int, pd.DataFrame] dfs

    :param pd.Index[str] variables

    :param int cores

    :rtype: pd.DataFrame
    """

    info('Calculating joint co-occurrences')

    # An iterator of tuples of (cluster, reference joint, co-occuring joint).

    jobs = tqdm.tqdm(
        it.product(dfs.keys(), variables, variables),
        total=len(dfs) * variables.size**2)

    results = pd.concat(
        jl.Parallel(n_jobs=cores)(jl.delayed(_get_co_occurrence)(k, i, dfs[k][
            i], j, dfs[k][j]) for k, i, j in jobs))

    for j in ['reference_site', 'co_occurring_site']:

        results[j] = results[j].astype('category')

    info('Result is a table with shape {}'.format(results.shape))

    return results


def write_output(df, filename):
    """
    Writes the given output to the given filename.

    :param pd.DataFrame df

    :param str filename
    """

    info('Writing output to {}'.format(filename))

    feather.write_dataframe(df, filename)


@click.command()
@click.option(
    '--original-input',
    type=click.File('rU'),
    required=True,
    help='read joint involvement data from ORIGINAL_INPUT')
@click.option(
    '--cluster-input',
    type=click.File('rU'),
    help='read cluster assignments from CLUSTER_INPUT')
@click.option(
    '--output', required=True, help='write output to Feather file OUTPUT')
@click.option(
    '--cores', type=int, default=-1, help='run the analysis on CORES cores')
def main(original_input, cluster_input, output, cores):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    data, clusters = load_data(original_input, cluster_input)

    splitted_data = split_data(data, clusters)

    co_occurrences = get_co_occurrences(splitted_data, data.columns, cores)

    write_output(co_occurrences, output)


if __name__ == '__main__':
    main()