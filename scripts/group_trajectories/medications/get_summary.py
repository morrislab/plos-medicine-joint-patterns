"""
Summarizes medications for patients who fail to reach zero joint involvement.
"""

import pandas as pd

from click import *
from logging import *


def aggregate(df: pd.DataFrame) -> pd.Series:
    """
    Computes statistics for the given data frame.

    Args:
        df: the data frame.
    """

    return pd.Series({
        'count': df['status'].sum(),
        'total': df.shape[0],
        'proportion': df['status'].mean()
    })


@command()
@option(
    '--input',
    required=True,
    help='the Feather file to read medication data from')
@option(
    '--output',
    required=True,
    help='the CSV file to output summarized statistics to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading medication data')

    medications = pd.read_feather(input)

    debug(f'Result: {medications.shape}')

    info('Summarizing medications')

    summary = medications.groupby(
        ['visit_id', 'baseline_classification', 'zero_joints',
         'medication']).apply(aggregate)

    info('Writing output')

    summary.to_csv(output)


if __name__ == '__main__':
    main()