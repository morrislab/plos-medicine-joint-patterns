"""
Bootstraps counts for localization assignments.
"""

import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *
from typing import *


def get_bootstrapped_count(localizations: pd.Series,
                           seed: int) -> Tuple[int, int]:
    """
    Counts the number of patients with limited involvement after one bootstrap
    iteration.

    Args:
        localizations: Localization assignments.
        seed: Seed to use for the permutation analysis.

    Returns:
        The seed and number of bootstrapped patients with limited involvement.
    """

    np.random.seed(seed)

    samples = np.random.choice(localizations, localizations.size, replace=True)

    return seed, (samples == 'limited').sum()


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to read classifications from')
@option('--seed-input', required=True, help='the text file to read seeds from')
@option(
    '--output',
    required=True,
    help='the CSV file to write bootstrapped counts to')
def main(data_input, seed_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input)

    if data['threshold'].unique().size != 1:

        raise ValueError('threshold must contain only one unique value')

    info('Result: {}'.format(data.shape))

    info('Loading seeds')

    with open(seed_input, 'r') as handle:

        seeds = [int(x) for x in handle]

    # Generate bootstrapped counts.

    info('Generating bootstrapped counts')

    counts = pd.DataFrame.from_records(
        (get_bootstrapped_count(data['localization'], seed)
         for seed in tqdm.tqdm(seeds)),
        columns=['seed', 'count'])

    # Write the output.

    info('Writing output')

    counts['threshold'] = data['threshold'].unique()[0]

    counts.to_csv(output, index=False)


if __name__ == '__main__':
    main()
