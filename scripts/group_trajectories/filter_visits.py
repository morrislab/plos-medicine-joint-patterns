"""
Extracts joint involvement data from relevant visits.
"""

import click
import feather
import pandas as pd
import tqdm

from logging import *


def get_contiguous_visits(df: pd.DataFrame) -> pd.DataFrame:
    """
    Reduces the given table for a single patient to contiguous visits,
    starting with baseline.

    Args:
        df: The table to process.

    Returns:
        A table containing contiguous visits.
    """

    # Patients must start at baseline.

    if df['visit_id'].min() != 1:

        return None

    shifts = df['visit_id'] - df['visit_id'].shift()

    # Determine where to cut things off.

    clip_ix = shifts.index[1:][shifts.iloc[1:] != 1]

    if clip_ix.size >= 1:

        return df.loc[:clip_ix[0]].head(-1)

    return df


@click.command()
@click.option(
    '--input', required=True, help='read input data from Feather file INPUT')
@click.option(
    '--visit',
    type=int,
    required=True,
    multiple=True,
    help='extract involvements from visit VISIT')
@click.option(
    '--output',
    required=True,
    help='output filtered involvements to CSV file OUTPUT')
def main(input, visit, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = feather.read_dataframe(input)

    data.info()

    info('Filtering visits')

    data = data.loc[data['visit_id'].isin(visit)]

    info('Ensuring contiguous visits for each patient')

    tqdm.tqdm.pandas()

    g = data.groupby('subject_id')

    contiguous_data = g.progress_apply(get_contiguous_visits)

    info('Writing data')

    contiguous_data.info()

    contiguous_data.to_csv(output, index=False)


if __name__ == '__main__':

    main()