"""
Calculates deltas for all pairs of joints.

We can partition a conditional co-involvement matrix into the following regions
of conditional probabilities:
-   Right | right
-   Right | left
-   Left | left
-   Left | right

This script outputs data for the following matrices:
-   Right | right - right | left
-   Left | left - left | right
"""

import pandas as pd

from click import *
from logging import *


def get_means(df: pd.DataFrame, *, matching_sides: bool,
              matching_roots: bool) -> pd.Series:
    """
    Calculates mean conditional probabilities from a given co-occurrence table
    with filters restricting for matching sides and roots.

    Args:
        df: The co-occurrences.
        matching_sides: Whether to consider pairs of sites with matching sides.
        matching_roots: Whether to consider pairs of sites with matching roots.

    Returns:
        The mean conditional probabilities.
    """

    return df.query('is_matching_sides == {} and '
                    '(reference_joint_type {} co_occurring_joint_type)'.format(
                        matching_sides, '=='
                        if matching_roots else '!=')).groupby([
                            'reference_joint_type', 'co_occurring_joint_type'
                        ])['conditional_probability'].mean()


def get_delta_co_occurring_joints(df: pd.DataFrame) -> float:
    """
    Calculates deltas for co-occurrences for a single side for a single co-
    occurring joints and reference joint type.

    Args:
        df: co-occurrences for a single side of co-occurring joints.
        side: side of the body for the co-occurring joints.

    Returns:
        Differences in co-involvement, namely P(y | x_(same side)) - P(y |
        x_(opposite side)), where y is a co-occurring joint/joint type and x is
        a reference joint type.
    """

    same_prob = df.loc[df['co_occurring_side'] == df['reference_side'],
                       'conditional_probability'].iloc[0]

    opposite_prob = df.loc[df['co_occurring_side'] != df['reference_side'],
                           'conditional_probability'].iloc[0]

    return same_prob - opposite_prob


def get_deltas(df: pd.DataFrame, side: str) -> pd.DataFrame:
    """
    Calculates deltas for co-occurrences for a single side for all combinations
    of co-occurring joints and reference joint types.

    Args:
        df: co-occurrences for a single side of co-occurring joints.
        side: side of the body for the co-occurring joints.

    Returns:
        Differences in co-involvement, namely P(y | x_(same side)) - P(y |
        x_(opposite side)), where y is a co-occurring joint/joint type and x is
        a reference joint type.
    """

    result = df.groupby(['co_occurring_joint', 'reference_type'])[[
        'co_occurring_side', 'reference_side', 'conditional_probability'
    ]].apply(get_delta_co_occurring_joints)

    result.name = 'delta'

    return result.reset_index()


@command()
@option(
    '--input',
    required=True,
    help='the Feather file containing the conditional co-occurrences')
@option('--output', required=True, help='the Feather file to write output to')
@option('--verbose/--no-verbose', default=False)
def main(input: str, output: str, verbose: bool):

    basicConfig(level=DEBUG if verbose else INFO)

    # Load the data.

    info('Loading data')

    co_occurrences = pd.read_feather(input)

    debug(f'Result: {co_occurrences.shape}')

    co_occurrences = co_occurrences[[
        'reference_joint', 'co_occurring_joint', 'conditional_probability'
    ]]

    # Drop joints not assigned to any one side.

    info('Dropping joints not assigned to any one side')

    all_joints = co_occurrences['reference_joint'].cat.categories.union(
        co_occurrences['co_occurring_joint'].cat.categories)

    joints_to_drop = all_joints[~(all_joints.str.contains(r'_(left|right)$'))]

    co_occurrences = co_occurrences.loc[
        ~(co_occurrences['reference_joint'].isin(joints_to_drop)
          | co_occurrences['co_occurring_joint'].isin(joints_to_drop))]

    debug(f'Result: {co_occurrences.shape}')

    # Calculate site types.

    info('Calculating site types')

    co_occurrences['reference_type'] = co_occurrences[
        'reference_joint'].str.extract(
            r'^(.+)_.+$', expand=False)

    co_occurrences['co_occurring_type'] = co_occurrences[
        'co_occurring_joint'].str.extract(
            r'^(.+)_.+$', expand=False)

    debug(f'Result: {co_occurrences.shape}')

    # Calculate the sides of the body.

    info('Calculating sides')

    co_occurrences['reference_side'] = co_occurrences[
        'reference_joint'].str.extract(
            r'_(left|right)$', expand=False)

    co_occurrences['co_occurring_side'] = co_occurrences[
        'co_occurring_joint'].str.extract(
            r'_(left|right)$', expand=False)

    debug(f'Result: {co_occurrences.shape}')

    # Calculate deltas for right joints and left joints separately.

    deltas = pd.concat(
        get_deltas(co_occurrences.query('co_occurring_side == @side'), side)
        for side in ['left', 'right'])

    # Write the output.

    info('Writing output')

    for j in ['co_occurring_joint', 'reference_type']:

        deltas[j] = deltas[j].astype('category')

    deltas.reset_index(drop=True).to_feather(output)


if __name__ == '__main__':
    main()
