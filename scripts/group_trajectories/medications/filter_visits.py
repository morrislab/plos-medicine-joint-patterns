"""
Filters future medication data for patients who do not reach zero joint
involvement by visit.
"""

import pandas as pd

from click import *
from logging import *
from typing import *


@command()
@option('--input', required=True, help='the Feather file to read input data')
@option(
    '--visit',
    type=IntRange(min=1),
    required=True,
    multiple=True,
    help='the visit numbers to filter to')
@option(
    '--output',
    required=True,
    help='the Feather file to output filtered data to')
def main(input: str, visit: Tuple[int], output: str):

    basicConfig(level=DEBUG)

    info('Loading data')

    data = pd.read_feather(input)

    debug(f'Result: {data.shape}')

    info('Filtering visits')

    data = data.loc[data['visit_id'].isin(list(visit))]

    debug(f'Result: {data.shape}')

    info('Writing output')

    data.reset_index(drop=True).to_feather(output)


if __name__ == '__main__':
    main()