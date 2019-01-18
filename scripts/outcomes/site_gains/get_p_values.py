"""
Calculates P-values from the permutation test.
"""

import feather
import functools as ft
import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *
from statsmodels.sandbox.stats.multicomp import multipletests


def get_stats(df: pd.DataFrame, df_baseline: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains statistics for the given data slice for a classification and site.

    Args:
        df: The data slice to compute statistics from.
        df_baseline: Baseline (unshuffled) statistics.

    Returns:
        The statistics.
    """

    baseline_n = df_baseline.loc[(df['classification'].unique()[0], df['site']
                                  .unique()[0]), 'n_gained']

    if baseline_n == 0:

        return pd.DataFrame({'n': [np.nan], 'p': [1.]})

    mask = df['n_gained'] > baseline_n

    return pd.DataFrame({'n': [mask.sum()], 'p': [mask.mean()]})


def correct_p_values(x: pd.Series) -> pd.Series:
    """
    Corrects P-values using the Holm-Bonferroni procedure.

    Args:
        x: P-values to correct.

    Returns:
        Corrected P-values.
    """

    return pd.Series(multipletests(x, method='holm')[1], index=x.index)


@command()
@option(
    '--base-input',
    required=True,
    help='the CSV file to load baseline information from')
@option(
    '--sample-input',
    required=True,
    help='the Feather file to load sample information from')
@option('--output', required=True, help='the CSV file to output statistics to')
def main(base_input, sample_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading baseline information')

    baseline = pd.read_csv(base_input, index_col=['classification', 'site'])

    info('Result: {}'.format(baseline.shape))

    info('Loading samples')

    samples = feather.read_dataframe(sample_input)

    info('Result: {}'.format(samples.shape))

    info('Calculating statistics')

    tqdm.tqdm.pandas()

    results = samples.groupby(['classification', 'site']).progress_apply(
        ft.partial(
            get_stats, df_baseline=baseline)).reset_index(
                ['classification', 'site']).reset_index(drop=True)

    info('Correcting P-values')

    results['p_adjust'] = results.groupby(
        ['classification'])['p'].apply(correct_p_values)

    info('Writing output')

    results.to_csv(output, index=False)


if __name__ == '__main__':
    main()