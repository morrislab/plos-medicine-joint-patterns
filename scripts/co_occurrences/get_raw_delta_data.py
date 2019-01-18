"""
Calculates deltas from raw co-occurrence probabilities.
"""

import feather
import pandas as pd

from click import *
from logging import *


def get_means(df: pd.DataFrame, *, matching_sides: bool,
              matching_roots: bool) -> pd.Series:
    """
    Calculates mean probabilities from a given co-occurrence table
    with filters restricting for matching sides and roots.

    Args:
        df: The co-occurrences.
        matching_sides: Whether to consider pairs of sites with matching sides.
        matching_roots: Whether to consider pairs of sites with matching roots.

    Returns:
        The mean conditional probabilities.
    """

    return df.query('is_matching_sides == {} and '
                    '(reference_site_root {} co_occurring_site_root)'.format(
                        matching_sides, '=='
                        if matching_roots else '!=')).groupby(
                            ['reference_site_root', 'co_occurring_site_root'])[
                                'probability'].mean()


@command()
@option(
    '--input',
    required=True,
    help='the Feather file containing the conditional co-occurrences')
@option('--output', required=True, help='the CSV file to write output to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    co_occurrences = feather.read_dataframe(input)

    info('Result: {}'.format(co_occurrences.shape))

    co_occurrences = co_occurrences[
        ['reference_joint', 'co_occurring_joint', 'probability']]

    # Drop joints not assigned to any one side.

    info('Dropping joints not assigned to any one side')

    all_joints = co_occurrences['reference_joint'].cat.categories.union(
        co_occurrences['co_occurring_joint'].cat.categories)

    joints_to_drop = all_joints[~(all_joints.str.contains(r'_(left|right)$'))]

    co_occurrences = co_occurrences.loc[~(co_occurrences[
        'reference_joint'].isin(joints_to_drop) | co_occurrences[
            'co_occurring_joint'].isin(joints_to_drop))]

    # Calculate root sites.

    info('Calculating root sites')

    co_occurrences['reference_site_root'] = co_occurrences[
        'reference_joint'].str.extract(
            r'^(.+)_.+$', expand=False)

    co_occurrences['co_occurring_site_root'] = co_occurrences[
        'co_occurring_joint'].str.extract(
            r'^(.+)_.+$', expand=False)

    # Calculate if sides match.

    info('Calculating side indicators')

    co_occurrences['reference_site_side'] = co_occurrences[
        'reference_joint'].str.extract(
            r'_(left|right)$', expand=False)

    co_occurrences['co_occurrence_site_side'] = co_occurrences[
        'co_occurring_joint'].str.extract(
            r'_(left|right)$', expand=False)

    co_occurrences['is_matching_sides'] = co_occurrences[
        'reference_site_side'] == co_occurrences['co_occurrence_site_side']

    # Calculate means in various configurations.

    info('Calculating means for matching sides, excluding diagonals')

    means_matching_sides_offdiagonal = get_means(
        co_occurrences, matching_sides=True, matching_roots=False)

    info('Calculating means for non-matching sides, excluding diagonals')

    means_nonmatching_sides_offdiagonal = get_means(
        co_occurrences, matching_sides=False, matching_roots=False)

    info('Calculating means for matching sides, including diagonals')

    means_matching_sides_diagonal = get_means(
        co_occurrences, matching_sides=True, matching_roots=True)

    info('Calculating means for non-matching sides, including diagonals')

    means_nonmatching_sides_diagonal = get_means(
        co_occurrences, matching_sides=False, matching_roots=True)

    # Calculate deltas.

    info('Calculating deltas')

    deltas_offdiagonal = (
        means_matching_sides_offdiagonal - means_nonmatching_sides_offdiagonal)

    deltas_diagonal = (
        means_matching_sides_diagonal - means_nonmatching_sides_diagonal)

    # Concatentate the deltas.

    info('Concatenating deltas')

    deltas = pd.concat(
        [deltas_offdiagonal.reset_index(), deltas_diagonal.reset_index()])

    deltas.rename(columns={'probability': 'delta'}, inplace=True)

    # Write the output.

    info('Writing output')

    deltas.to_csv(output, index=False)


if __name__ == '__main__':
    main()
