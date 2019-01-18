"""
With cluster assignments, assign patients as localized or diffuse on underlying
factors based on what sites are involved.

For each patient, consider the cluster assignment and that cluster's underlying
factor. If all sites involved are representative for that factor, that patient
is localized on that factor. Otherwise, it is diffuse on that factor.
"""

import feather
import functools as ft
import pandas as pd

from click import *
from logging import *


def get_localization_label(df: pd.DataFrame,
                           df_clusters: pd.DataFrame,
                           df_representative_sites: pd.DataFrame) -> str:
    """
    Determines whether a patient with involved sites, from the given data
    frame, has involvement that is localized to the factor underlying its
    cluster assignment.

    Args:
        df: Data frame of involved sites and cluster assignment.
        df_clusters: Cluster assignments.
        df_representative_sites: Data frame of representative sites.

    Returns:
        A label describing whether the patient's involvement is localized.
    """

    cluster = df_clusters.loc[df.iloc[0]['subject_id'], 'classification']

    cluster_sites = df_representative_sites.loc[[cluster]]

    non_representative_sites = set(df['site']) - set(cluster_sites['site'])

    return 'localized' if len(non_representative_sites) == 0 else 'diffuse'


@command()
@option(
    '--site-input',
    required=True,
    help='the Feather file to read site involvements from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--representative-site-input',
    required=True,
    help='the CSV file to read representative sites from')
@option(
    '--output',
    required=True,
    help='the CSV file to write cluster assignments to')
def main(site_input, cluster_input, representative_site_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading sites')

    sites = feather.read_dataframe(site_input)

    info('Result: {}'.format(sites.shape))

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col='subject_id')

    info('Result: {}'.format(clusters.shape))

    info('Loading representative sites')

    representative_sites = pd.read_csv(
        representative_site_input, index_col='factor')

    info('Result: {}'.format(representative_sites.shape))

    info('Filtering and melting sites')

    sites = sites.loc[sites['subject_id'].isin(clusters.index) & (sites[
        'visit_id'] == 1)].drop(
            'visit_id', axis=1)

    sites_melted = pd.melt(sites, id_vars=['subject_id'], var_name='site')

    info('Determining localization')

    involved_sites = sites_melted.loc[sites_melted['value'] > 0].drop(
        'value', axis=1)

    clusters['localization'] = involved_sites.groupby('subject_id').apply(
        ft.partial(
            get_localization_label,
            df_clusters=clusters,
            df_representative_sites=representative_sites))

    info('Writing output')

    clusters.to_csv(output)


if __name__ == '__main__':
    main()