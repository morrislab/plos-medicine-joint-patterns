"""
Calculates time to zero involvement per patient.
"""

import feather
import pandas as pd

from click import *
from logging import *


def get_time_to_zero(df: pd.DataFrame) -> float:
    """
    Calculates the time to zero, by visit number.

    Args:
        df: Future cluster assignments.

    Returns:
        The visit number, or `np.nan` if the patient doesn't go to zero.
    """

    return df.loc[df['classification'] == '0', 'visit_id'].min()


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to load cluster trajectories from')
@option('--output', required=True, help='the Feather file to write times to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    df = pd.read_csv(input)

    info('Result: {}'.format(df.shape))

    # Obtain baseline cluster assignments.

    info('Obtaining baseline clusters')

    baseline_clusters = df.loc[df['visit_id'] == 1,
                               ['subject_id', 'classification']]

    # Calculate times per patient.

    info('Calculating times to zero')

    times = df.groupby(
        ['subject_id'])[['visit_id', 'classification']].apply(get_time_to_zero)

    times.name = 'first_zero_visit'

    # Merge baseline clusters in.

    info('Merging baseline clusters')

    times = times.to_frame().merge(
        baseline_clusters, left_index=True, right_on='subject_id')

    # Write the output.

    info('Writing output')

    times['classification'] = times['classification'].astype('category')

    feather.write_dataframe(times, output)


if __name__ == '__main__':
    main()