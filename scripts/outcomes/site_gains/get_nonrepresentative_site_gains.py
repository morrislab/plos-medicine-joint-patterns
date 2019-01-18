"""
Calculates, for each patient, which sites they gain at any time point into the
future given future visits.
"""

import feather
import pandas as pd
import tqdm

from click import *
from logging import *
from typing import *


def filter_representative_sites_patient(
        df: pd.DataFrame, representative_sites: List[str]) -> pd.DataFrame:
    """
    Filters out representative sites from the given data frame for a single
    patient.

    Args:
        df: The data frame to filter.
        representative_sites: Representative sites to filter out.

    Returns:
        The filtered data.
    """

    return df.loc[~(df['site'].isin(representative_sites))]


def filter_representative_sites(
        df: pd.DataFrame, clusters: pd.Series,
        representative_sites: pd.DataFrame) -> pd.DataFrame:
    """
    Filters out representative sites from the given data frame.

    Args:
        df: The data frame to filter.
        clusters: Cluster assignments.
        representative_sites: Representative sites for each cluster.

    Returns:
        The filtered data.
    """

    return pd.concat(
        filter_representative_sites_patient(
            df.loc[df['subject_id'] == i],
            representative_sites.loc[[clusters.loc[i]]]['site'].tolist())
        for i in tqdm.tqdm(clusters.index))


def get_differences(df_future: pd.DataFrame,
                    df_baseline: pd.DataFrame) -> pd.DataFrame:
    """
    Calculates differences between future involvements and baseline involvements.

    Args:
        df_future: Involvements in the future.
        df_baseline: Involvements at baseline.

    Returns:
        The differences.
    """

    return (
        df_future.set_index(['subject_id', 'site']) - df_baseline.set_index(
            ['subject_id', 'site'])).reset_index().dropna(subset=['value'])


@command()
@option(
    '--cluster-input',
    required=True,
    help='the CSV file containing cluster assignments')
@option(
    '--representative-site-input',
    required=True,
    help='the CSV file containing representative sites')
@option(
    '--site-input',
    required=True,
    help='the Feather file containing site involvements')
@option(
    '--visit',
    required=True,
    multiple=True,
    help='the future visit numbers to consider (multiple allowed)')
@option(
    '--output',
    required=True,
    help='the Feather file to output gain information to')
def main(cluster_input, representative_site_input, site_input, visit, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0, squeeze=True)

    info('Result: {}'.format(clusters.shape))

    info('Loading representative sites')

    representative_sites = pd.read_csv(
        representative_site_input, index_col='factor')

    info('Result: {}'.format(representative_sites.shape))

    info('Loading involvements')

    involvements = feather.read_dataframe(site_input)

    info('Result: {}'.format(involvements.shape))

    # Filter the data to the relevant visits and patients.

    info('Filtering data to relevant visits and patients')

    subject_id_mask = involvements['subject_id'].isin(clusters.index)

    involvements_baseline = involvements.loc[subject_id_mask & (involvements[
        'visit_id'] == 1)].drop(
            'visit_id', axis=1)

    involvements_future = involvements.loc[subject_id_mask & involvements[
        'visit_id'].isin(visit)]

    # Among future involvements, calculate whether sites were involved at any
    # time in the future.

    involvements_future_any = involvements_future.drop(
        'visit_id', axis=1).groupby('subject_id').max()

    # Melt all involvements.

    info('Melting involvements')

    involvements_baseline_melted = involvements_baseline.melt(
        id_vars='subject_id', var_name='site')

    involvements_future_melted = involvements_future_any.reset_index().melt(
        id_vars='subject_id', var_name='site')

    # For each patient, filter all involvements to non-representative sites.

    info('Filtering involvements to non-representative sites')

    involvements_baseline_nonrep = filter_representative_sites(
        involvements_baseline_melted, clusters, representative_sites)

    involvements_future_nonrep = filter_representative_sites(
        involvements_future_melted, clusters, representative_sites)

    # Calculate differences between baseline and future.

    # differences = involvements_future_melted.set_index(
    #     ['subject_id', 'site']) - involvements_baseline_melted.set_index(
    #         ['subject_id', 'site'])

    differences_nonrep = get_differences(involvements_future_nonrep,
                                         involvements_baseline_nonrep)

    # Merge the cluster assignments in.

    info('Merging cluster assignments')

    differences_nonrep = differences_nonrep.merge(
        clusters.to_frame(),
        how='inner',
        left_on='subject_id',
        right_index=True)

    # Write the output.

    info('Writing output')

    for j in ['subject_id', 'site', 'classification']:

        differences_nonrep[j] = differences_nonrep[j].astype('category')

    feather.write_dataframe(differences_nonrep, output)


if __name__ == '__main__':
    main()