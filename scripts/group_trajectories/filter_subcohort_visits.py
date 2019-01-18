"""
Filters subcohorts by visit.
"""

import functools as ft
import pandas as pd

from click import *
from logging import *


def filter_visits(df: pd.DataFrame, max_visit: int) -> pd.DataFrame:
    """
    Filters visits to consecutive visits, up to a given visit.

    Args:
        df: The data to filter.
        max_visit: The maximum visit to consider.

    Returns:
        The filtered data.
    """

    df = df.query('visit_id <= @max_visit')

    import IPython
    IPython.embed()
    raise Exception()


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read input subcohort assignments from')
@option(
    '--output',
    required=True,
    help='the CSV file to output filtered subcohort assignments to')
@option(
    '--max-visit',
    type=int,
    required=True,
    help='the maximum visit to filter subcohort assignments to')
def main(input, output, max_visit):

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

    # Filter the info.

    info('Filtering data')

    g = data.groupby('subject_id')

    filtered_data = g.apply(ft.partial(filter_visits, max_visit=max_visit))


if __name__ == '__main__':
    main()