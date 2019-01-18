"""
Calculates probabilities of gaining sites at future time points.
"""

import feather
import pandas as pd

from click import *
from logging import *
from typing import *


def get_stats(x: pd.Series) -> pd.DataFrame:
    """
    Calculates the gain probability from the given series, as well as the
    number of patients considered and the number of patients who gained the
    site specified by the series.

    Args:
        x: An indicator specifying whether a patient has gained involvement in
            a site at any future time point.

    Returns:
        The gain probability, the number of patients considered, and the number
        of patients gaining involvement in the site specified by the input.
    """

    mask = x > 0

    return pd.DataFrame({
        'n': [x.size],
        'n_gained': [mask.sum()],
        'probability': [mask.mean()]
    })


@command()
@option(
    '--input',
    required=True,
    help='the Feather file containing calculated site gains')
@option(
    '--output',
    required=True,
    help='the CSV file to output gain probabilities to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(input)

    info('Result: {}'.format(data.shape))

    # Calculate stats.

    info('Calculating statistics')

    stats = data.groupby(
        ['classification', 'site'])['value'].apply(get_stats).reset_index(
            ['classification', 'site'])

    # Write the output.

    info('Writing output')

    stats.to_csv(output, index=False)


if __name__ == '__main__':
    main()