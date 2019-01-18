"""
Counts the number of patients with same-side pairings and the number with
opposite-side pairings.

We first calculate a quality `P = (n_{same side} + c) / (n_{same side} +
n_opposite side + 2c)`, where `c` is a constant to avoid division by zero. We
note that a patient can be counted twice. For example, a patient can have both a
same-side hip and an opposite-side hip involved.

We then calculate Z-scores by first calculating `sigma = sqrt(p * (1 - p) / n)`,
then `z = (p - 0.5) / sigma`.
"""

from click import *
from logging import *

import itertools as it
import numpy as np
import pandas as pd
import tqdm

SIDES = ['left', 'right']


def get_statistics(X: pd.DataFrame, reference_type: str, conditional_type: str,
                   c: float) -> pd.DataFrame:
    """
    Obtains statistics for the given site type.

    Args:
        X: site involvement data
        reference_type: the reference site type
        conditional_type: the conditional site type
        c: a constant to prevent division by zero

    Returns:
        statistics as above
    """

    # Determine sites to extract.

    reference_sites = {
        side: f'{x}_{side}'
        for x, side in it.product([reference_type], SIDES)
    }

    conditional_sites = {
        side: f'{x}_{side}'
        for x, side in it.product([conditional_type], SIDES)
    }

    # Calculate same-side and opposite-side masks.

    left_same_mask = X[reference_sites['left']] & X[conditional_sites['left']]

    right_same_mask = X[reference_sites['right']] & X[conditional_sites['right']]

    left_opposite_mask = X[reference_sites['left']] & X[conditional_sites['right']]

    right_opposite_mask = X[reference_sites['right']] & X[conditional_sites['left']]

    # Calculate quantities.

    n = (left_same_mask | right_same_mask | left_opposite_mask
         | right_opposite_mask).sum()

    n_same = (left_same_mask | right_same_mask).sum()

    n_opposite = (left_opposite_mask | right_opposite_mask).sum()

    # Calculate P.

    p = (n_same + c) / (n_same + n_opposite + 2 * c)

    # Calculate sigma.

    sigma = np.sqrt(p * (1 - p) / n)

    # Calculate z.

    z = (p - 0.5) / sigma

    # Return the result.

    return pd.DataFrame(
        {
            'reference_type': reference_type,
            'conditional_type': conditional_type,
            'n': n,
            'n_same': n_same,
            'n_opposite': n_opposite,
            'p': p,
            'sigma': sigma,
            'z': z
        },
        index=[0])


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read site involvement data from')
@option('--output', required=True, help='the Feather file to write output to')
@option(
    '--c',
    type=float,
    default=1.,
    help='the constant to add to avoid division by zero')
def main(input, output, c):

    basicConfig(level=DEBUG)

    # Load data.

    info('Loading data')

    X = pd.read_csv(input, index_col='subject_id')

    debug(f'Result: {X.shape}')

    # Drop unpaired sites.

    info('Dropping unpaired sites')

    paired_mask = X.columns.str.contains(r'_(left|right)$')

    X = X.loc[:, paired_mask]

    debug(f'Result: {X.shape}')

    # Determine site types.

    info('Determining site types')

    site_types = sorted(X.columns.str.replace(r'_(left|right)$', '').unique())

    debug(f'Result: {len(site_types)} site types')

    # Calculate statistics.

    info('Calculating statistics')

    statistics = pd.concat(
        get_statistics(X, reference_type=x, conditional_type=y, c=c)
        for x, y in tqdm.tqdm(
            it.product(site_types, site_types), total=len(site_types)**2))

    statistics = statistics.set_index(['reference_type', 'conditional_type'])

    debug(f'Result: {statistics.shape}')

    # Write output.

    info('Writing output')

    statistics.reset_index().to_feather(output)


if __name__ == '__main__':
    main()