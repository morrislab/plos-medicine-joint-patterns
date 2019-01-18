"""
Obtains log P-value ratios.
"""

import numpy as np
import pandas as pd

from click import *
from logging import *


def get_log_ratio(df: pd.DataFrame) -> float:
    """
    Obtains a log10 ratio: P(same | x) / P(opposite | x), where y is a co-
    occurring joint type and x is a reference joint.

    Args:
        df: data frame containing P(same | x) and P(opposite | x)
    """

    reference_side = df['reference_side'].iloc[0]

    opposite_side = 'left' if reference_side == 'right' else 'right'

    df = df.set_index('co_occurring_side')

    return -(np.log10(df.loc[reference_side, 'p_adjusted'] /
                      df.loc[opposite_side, 'p_adjusted']))


@command()
@option('--input', required=True, help='the CSV file to read P-values from')
@option(
    '--output',
    required=True,
    help='the CSV file to output log P-value ratios to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading frequencies')

    probs = pd.read_csv(input)

    debug(f'Result: {probs.shape}')

    # Filter out sideless sites.

    probs = probs.loc[probs['reference'].str.contains(r'_(left|right)$')
                      & probs['co_occurring'].str.contains(r'_(left|right)$')]

    # Calculate the type of site for each co-occurring site.

    probs['co_occurring_side'] = probs['co_occurring'].str.extract(
        r'_(left|right)$')

    probs['co_occurring_type'] = probs['co_occurring'].str.extract(
        r'^(.+)_.+?$')

    probs['reference_side'] = probs['reference'].str.extract(r'_(left|right)$')

    probs['reference_type'] = probs['reference'].str.extract(r'^(.+)_.+?$')

    info('Calculating ratios')

    ratios = probs.groupby(['reference',
                            'co_occurring_type']).apply(get_log_ratio)

    ratios.name = 'ratio'

    ratios = ratios.reset_index()

    info('Writing output')

    ratios.to_csv(output, index=False)


if __name__ == '__main__':
    main()