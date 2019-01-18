"""
Produces heat map data that describes, for each patient group, the probability
of reaching any other patient group at any time point.
"""

import feather
import itertools as it
import joblib as jl
import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *


def get_transition_probability(df_reference: pd.DataFrame,
                               df_future: pd.DataFrame,
                               source_group: str,
                               target_group: str) -> pd.DataFrame:
    """
    Obtains transition probabilities from a given reference patient group to
    other patient groups at any visit.

    Args:
        df_reference: The reference patient groups.
        df_future: The future patient groups.
        source_group: The reference patient group.
        target_group: The target patient group.

    Returns:
        The transition probability.
    """

    df_reference = df_reference.loc[df_reference['classification'] ==
                                    source_group].drop(
                                        'visit_id',
                                        axis=1).set_index('subject_id')

    df_future = df_future.set_index('subject_id')

    df_future = df_future.loc[df_reference.index & df_future.index]

    if df_future.shape[0] < 1:

        return None

    is_target = pd.Series(
        df_future['classification'] == target_group,
        name='is_target').reset_index()

    is_target_merged = is_target.groupby('subject_id')['is_target'].max()

    return pd.DataFrame(
        {
            'source': source_group,
            'target': target_group,
            'probability': is_target_merged.mean(),
            'count': is_target_merged.sum()
        },
        index=[0])


def permute_visit(df: pd.DataFrame) -> pd.DataFrame:
    """
    Permutes labels for a given visit.

    Args:
        df: The data frame of labels to permute.

    Returns:
        The permuted labels.
    """

    df = df.copy()

    df['classification'] = df['classification'].sample(frac=1).values

    return df


def do_permutation(df_reference: pd.DataFrame,
                   df_future: pd.DataFrame,
                   seed: int) -> pd.DataFrame:
    """
    Conducts a permutation test with the given reference classifications,
    future classifications, and seed.
    """

    # Permute the reference and future data.

    np.random.seed(seed)

    df_reference_shuffled = permute_visit(df_reference)

    unique_visits = sorted(df_future['visit_id'].unique())

    df_future_shuffled = pd.concat(
        permute_visit(df_future.query('visit_id == @i'))
        for i in unique_visits)

    reference_groups = sorted(df_reference_shuffled['classification'].unique())

    future_groups = sorted(df_future_shuffled['classification'].unique())

    result = pd.concat(
        get_transition_probability(df_reference_shuffled, df_future_shuffled,
                                   source_group, target_group)
        for source_group, target_group in it.product(reference_groups,
                                                     future_groups))

    result['seed'] = seed

    return result


@command()
@option('--input', required=True, help='read input data from CSV file INPUT')
@option('--seedlist', required=True, help='read seeds from text file SEEDLIST')
@option('--output', required=True, help='write output data to CSV file OUTPUT')
@option(
    '--reference-visit',
    type=int,
    default=1,
    help=('calculate probabilities from reference visits REFERENCE_VISIT '
          '(default: 1)'))
@option(
    '--cores', type=int, default=1, help='utilize CORES cores (default: 1)')
def main(input, seedlist, output, reference_visit, cores):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(input)

    data.info()

    # Load the list of seeds.

    info('Loading list of seeds')

    with open(seedlist, 'rU') as handle:

        seeds = [int(x) for x in handle]

    info('Loaded {} seeds'.format(len(seeds)))

    # Split the data into the reference visit and beyond.

    info('Splitting data')

    reference_data = data.query('visit_id == @reference_visit')

    future_data = data.query('visit_id > @reference_visit')

    # Conduct the permutation test per seed.

    info('Generating permutations')

    iterator = tqdm.tqdm(seeds)

    results = (
        do_permutation(reference_data, future_data, seed)
        for seed in iterator) if cores == 1 else jl.Parallel(cores=cores)(
            jl.delayed(do_permutation)(reference_data, future_data, seed)
            for seed in iterator)

    permutations = pd.concat(results)

    for j in ['seed', 'source', 'target']:

        permutations[j] = permutations[j].astype('category')

    # Write the output.

    info('Writing output')

    permutations.info()

    feather.write_dataframe(permutations, output)


if __name__ == '__main__':
    main()