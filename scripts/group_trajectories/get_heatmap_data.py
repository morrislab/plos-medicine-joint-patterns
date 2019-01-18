"""
Produces heat map data for trajectories between consecutive points.
"""

import itertools as it
import pandas as pd

from click import *
from logging import *


def get_heatmap_data(df: pd.DataFrame,
                     visit1: float,
                     visit2: float,
                     field: str) -> pd.DataFrame:
    """
    Obtains bubbleplot data for two consecutive visits.

    Args:
        df: The input data frame.
        visit1: The first visit.
        visit2: The second visit.
        field: The field to extract classifications from.

    Returns:
        The bubble plot data for the two visits.
    """

    df_visit1 = df.query('visit_id == @visit1').drop(
        'visit_id',
        axis=1).set_index('subject_id').rename(columns={field: 'cls_1'})

    df_visit2 = df.query('visit_id == @visit2').drop(
        'visit_id',
        axis=1).set_index('subject_id').rename(columns={field: 'cls_2'})

    df_merged = df_visit1.join(df_visit2, how='inner')

    counts = pd.DataFrame({
        'count': df_merged.groupby(['cls_1', 'cls_2']).size()
    }).reset_index()

    totals = counts.groupby('cls_1')['count'].sum()

    counts.set_index('cls_1', inplace=True)

    counts.eval('pct = 100 * count / @totals', inplace=True)

    counts.eval('visit1 = @visit1', inplace=True)

    counts.eval('visit2 = @visit2', inplace=True)

    return counts.reset_index()


@command()
@option('--input', required=True, help='the CSV file to read input data from')
@option('--output', required=True, help='the CSV file to output data to')
@option(
    '--field',
    default='classification',
    help=('the name of the field to extract classifications from (default: '
          'classification)'))
def main(input, output, field):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(input)

    data.info()

    # Create heat map data between pairs of visits.

    info('Generating heat map data')

    visits = sorted(data['visit_id'].unique())

    visit_iterator = it.combinations(visits, 2)

    heatmap_data = pd.concat(
        get_heatmap_data(data, v1, v2, field) for v1, v2 in visit_iterator)

    # Write the output.

    info('Writing output')

    heatmap_data.info()

    heatmap_data.to_csv(output, index=False)


if __name__ == '__main__':
    main()