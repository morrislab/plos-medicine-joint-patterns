"""
Produces heat map data that describes, for each patient group, the probability
of reaching any other patient group at any time point.
"""

import itertools as it
import pandas as pd

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

    df_reference = df_reference.query('classification == @source_group').drop(
        'visit_id', axis=1).set_index('subject_id')

    df_future = df_future.set_index('subject_id')

    df_future = df_future.loc[df_reference.index & df_future.index]

    if df_future.shape[0] < 1:

        return None

    df_future.eval(
        'is_target = (classification == @target_group)', inplace=True)

    future_merged = df_future.groupby('subject_id')['is_target'].max()

    return pd.DataFrame(
        {
            'source': source_group,
            'target': target_group,
            'probability': future_merged.mean(),
            'count': future_merged.sum()
        },
        index=[0])


@command()
@option(
    '--input',
    required=True,
    metavar='INPUT',
    help='read input data from CSV file INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='write output data to CSV file OUTPUT')
@option(
    '--reference-visit',
    type=int,
    default=1,
    help=('calculate probabilities from reference visits REFERENCE_VISIT '
          '(default: 1)'))
def main(input, output, reference_visit):

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

    # Split the data into the reference visit and beyond.

    info('Splitting data')

    reference_data = data.query('visit_id == @reference_visit')

    future_data = data.query('visit_id > @reference_visit')

    # For each reference visit patient group, calculate transition
    # probabilities to other patient groups at any time point.

    info('Calculating transition probabilities')

    reference_groups = sorted(reference_data['classification'].unique())

    future_groups = sorted(future_data['classification'].unique())

    probabilities = pd.concat(
        get_transition_probability(reference_data, future_data, source_group,
                                   target_group)
        for source_group, target_group in it.product(reference_groups,
                                                     future_groups))

    # Write the output.

    info('Writing output')

    probabilities.info()

    probabilities.to_csv(output, index=False)


if __name__ == '__main__':
    main()