"""
Combines medication statistics for various sublocalizations.
"""

import pandas as pd

from click import *
from logging import *
from typing import *


def load_data(path: str, sublocalization: str) -> pd.DataFrame:
    """
    Loads data from the given path and with the given sublocalization.

    Args:
        path: the path to load data from.
        sublocalization: the sublocalization to assign to the loaded data.
    """

    debug(f'Loading {path!r}')

    result = pd.read_csv(path)

    debug(f'Result: {result.shape}')

    result['sublocalization'] = sublocalization

    return result


@command()
@option(
    '--input',
    required=True,
    multiple=True,
    help='the CSV files to read inputs from')
@option(
    '--sublocalization',
    required=True,
    multiple=True,
    help='the sublocalizations to assign to each input')
@option('--output', required=True, help='the Excel file to write output to')
def main(input: Tuple[str], sublocalization: Tuple[str], output: str):

    if len(input) != len(sublocalization):

        raise UsageError(
            'number of --inputs must match the number of --sublocalizations')

    basicConfig(level=DEBUG)

    info('Loading data')

    data = [load_data(i, s) for i, s in zip(input, sublocalization)]

    info('Concatenating data')

    data = pd.concat(data)

    debug(f'Result: {data.shape}')

    info('Writing output')

    data.set_index(['cls', 'sublocalization'], inplace=True)

    data.to_excel(output, merge_cells=False)


if __name__ == '__main__':
    main()