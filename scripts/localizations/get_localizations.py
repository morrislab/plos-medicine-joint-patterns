"""
Assigns patients in patient groups as having limited, partially limited, or
undifferentiated involvement.
"""

import functools as ft
import pandas as pd
import string
import tqdm

from click import *
from logging import *


def get_assignments(classification_sites: pd.DataFrame, basis: pd.DataFrame,
                    limited_threshold: float) -> str:
    """
    Obtains a localization assignment from the given classification and site
    for a given patient and a basis matrix.

    Args:
        classification_sites: classification and sites.
        basis: basis matrix.
        limited_threshold: the minimum proportion of involved sites that must
            fall under the same underlying factor to determine localization.

    Returns:
        The localization assignment.
    """

    classification = classification_sites['classification'].iloc[0]

    sites = set(classification_sites['site'].tolist())

    basis_entries = set(basis.index[basis[classification] > 0].tolist())

    unmatched_sites = sites - basis_entries

    proportion_matched_sites = 1 - len(unmatched_sites) / len(sites)

    return ('limited' if proportion_matched_sites >= limited_threshold else
            'undifferentiated')


@command()
@option(
    '--data-input',
    required=True,
    help='the Feather file to read site involvement data from')
@option(
    '--basis-input',
    required=True,
    help='the CSV file to read the basis matrix from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--limited-threshold',
    type=float,
    default=1.,
    help=('the minimum proportion of involved sites that must fall under the '
          'same underlying factor to call localization (default: 1)'))
@option(
    '--output',
    required=True,
    help='the CSV file to write types of involvement to')
def main(data_input: str, basis_input: str, cluster_input: str,
         limited_threshold: float, output: str):

    basicConfig(level=DEBUG)

    # Load the data.

    info('Loading site involvement data')

    data = pd.read_feather(data_input)

    debug(f'Result: {data.shape}')

    info('Loading basis matrix')

    basis = pd.read_csv(basis_input, index_col=0)

    debug(f'Result: {basis.shape}')

    info('Loading cluster assignments')

    clusters = pd.read_csv(cluster_input, index_col=0)

    debug(f'Result: {clusters.shape}')

    # Rename the basis matrix headers.

    info('Renaming basis matrix columns')

    basis.columns = [string.ascii_uppercase[int(i) - 1] for i in basis.columns]

    # Filter data.

    info('Filtering data')

    data = data.query('visit_id == 1').drop(
        'visit_id', axis=1).set_index('subject_id').join(
            clusters, how='inner')

    # Melt the data.

    info('Melting data')

    data_melted = pd.melt(
        data.reset_index(),
        id_vars=['subject_id', 'classification'],
        var_name='site').query('value > 0').drop(
            'value', axis=1)

    # Obtain assignments.

    info('Obtaining assignments')

    get_assignments_partial = ft.partial(
        get_assignments, basis=basis, limited_threshold=limited_threshold)

    tqdm.tqdm.pandas()

    assignments = data_melted.groupby('subject_id').progress_apply(
        get_assignments_partial)

    assignments.name = 'localization'

    # Merge the clusters in again.

    info('Merging clusters')

    merged = clusters.join(assignments.to_frame())

    # Add the threshold.

    merged['threshold'] = limited_threshold

    # Write the output.

    info('Writing output')

    merged.to_csv(output)


if __name__ == '__main__':
    main()
