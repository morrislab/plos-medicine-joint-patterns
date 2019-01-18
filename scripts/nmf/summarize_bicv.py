"""
Summarizes bi-cross-validation results.
"""

import feather
import numpy as np
import pandas as pd

from click import *
from logging import *


def se(x: pd.Series) -> float:
    """
    Calculates a standard error from the given series.

    Args:
        x: Values to calculate a standard error from.

    Returns:
        The standard error.
    """

    return x.std() / np.sqrt(x.shape[0])


@command()
@option('--input', required=True, help='the Feather file to read samples from')
@option('--output', required=True, help='the CSV file to write outputs to')
@option(
    '--parameter',
    required=True,
    multiple=True,
    type=Choice(['k', 'alpha']),
    help='the parameters to calculate summaries for')
def main(input, output, parameter):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the read_dataframe.

    info('Loading samples')

    df_samples = feather.read_dataframe(input)

    info('Result: {}'.format(df_samples.shape))

    # Calculate summaries.

    info('Calculating summaries')

    df_samples = df_samples.loc[df_samples['q2'] >= 0]

    df_summary = df_samples.groupby(parameter)['q2'].agg(['mean', 'std', se])

    # Write the output.

    info('Writing output')

    df_summary.to_csv(output)


if __name__ == '__main__':
    main()