"""
Obtains patient group trajectories, considering oligo-n and non-oligo-n
criteria.
"""

import feather
import functools as ft
import operator
import pandas as pd
import string
import tqdm

from click import *
from logging import *
from typing import *


def get_l1_patient_group(x: pd.DataFrame) -> str:
    """
    Obtains a level 1 patient group for given level 1 scores for a patient-
    visit.

    Args:
        x: Level 1 scores.

    Returns:
        The patient group.
    """

    return '{:02d}'.format(x.set_index('factor')['score'].argmax())


def get_l2_patient_group(x: pd.DataFrame) -> str:
    """
    Obtains a level 2 patient group for given level 2 scores for a patient-
    visit.

    Args:
        x: Level 2 scores.

    Returns:
        The patient group.
    """

    return string.ascii_uppercase[x.set_index('factor')['score'].argmax() - 1]


def get_patient_groups(df_l1_scores: pd.DataFrame,
                       df_l2_scores: pd.DataFrame,
                       subcohorts: pd.Series) -> pd.DataFrame:
    """
    Obtains patient group assignments for given level 1 scores, level 2 scores,
    and subcohorts.

    Args:
        df_l1_scores: Level 1 scores.
        df_l2_scores: Level 2 scores.
        subcohorts: Subcohort assignments.

    Returns:
        Patient group assignments for patient-visits.
    """

    # Withhold patients in the zero subcohort.

    zero_keys = subcohorts.index[subcohorts == 'zero']

    df_l1_scores = df_l1_scores.drop(zero_keys, axis=0)

    df_l2_scores = df_l2_scores.drop(zero_keys, axis=0)

    # Obtain assignments for localized oligos.

    l1_ids = subcohorts.index[subcohorts == 'localized_oligo']

    df_l1_scores = df_l1_scores.loc[df_l1_scores.index & l1_ids]

    l1_clusters = df_l1_scores.reset_index().groupby(
        ['subject_id', 'visit_id']).apply(get_l1_patient_group)

    l1_clusters.name = 'classification'

    l1_clusters = l1_clusters.reset_index()

    # Obtain assignments for diffuse oligos and non-oligos.

    l2_ids = subcohorts.index[subcohorts.isin(['diffuse_oligo', 'non_oligo'])]

    df_l2_scores = df_l2_scores.loc[df_l2_scores.index & l2_ids]

    l2_clusters = df_l2_scores.reset_index().groupby(
        ['subject_id', 'visit_id']).apply(get_l2_patient_group)

    l2_clusters.name = 'classification'

    l2_clusters = l2_clusters.reset_index()

    # Generate the assignments for the zero keys.

    zero_clusters = pd.DataFrame(
        {
            'classification': '--'
        }, index=zero_keys).reset_index()

    return pd.concat([l1_clusters, l2_clusters, zero_clusters]).sort_values(
        ['subject_id', 'visit_id'])


@command()
@option(
    '--data-input',
    required=True,
    metavar='DATA-INPUT',
    help='read site involvement data from Feather file DATA-INPUT')
@option(
    '--subcohort-input',
    required=True,
    metavar='SUBCOHORT-INPUT',
    help='read subcohort information from Feather file SUBCOHORT-INPUT')
@option(
    '--l1-basis-input',
    required=True,
    metavar='L1-BASIS-INPUT',
    help='read the level 1 basis from CSV file L1-BASIS-INPUT')
@option(
    '--l1-score-input',
    required=True,
    metavar='L1-SCORE-INPUT',
    help='read level 1 scores from CSV file L1-SCORE-INPUT')
@option(
    '--l2-score-input',
    required=True,
    metavar='L2-SCORE-INPUT',
    help='read level 2 scores from CSV file L2-SCORE-INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='write patient group assignments to CSV file OUTPUT')
@option(
    '--n', type=int, required=True, metavar='N', help='apply oligo-N criteria')
def main(data_input, subcohort_input, l1_basis_input, l1_score_input,
         l2_score_input, output, n):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading data')

    data = feather.read_dataframe(data_input).set_index(
        ['subject_id', 'visit_id'])

    data.info()

    info('Reading subcohort information')

    subcohorts = pd.read_csv(
        subcohort_input, index_col=['subject_id', 'visit_id'], squeeze=True)

    info('Loaded {} entries'.format(subcohorts.size))

    info('Loading basis')

    l1_basis = pd.read_csv(l1_basis_input, index_col=0)

    l1_basis.info()

    info('Loading level 1 scores')

    l1_scores = pd.read_csv(l1_score_input, index_col=[0, 1])

    l1_scores.info()

    info('Loading level 2 scores')

    l2_scores = pd.read_csv(l2_score_input, index_col=[0, 1])

    l2_scores.info()

    # Filter the data down to patients with level 1 and level 2 scores.

    info('Filtering subcohort information')

    subcohorts = subcohorts.loc[l1_scores.index & l2_scores.index]

    info('Filtering joint involvement data')

    data = data.loc[l1_scores.index & l2_scores.index & subcohorts.index]

    data.info()

    # Generate the patient group assignments.

    info('Getting patient group assignments')

    patient_groups = get_patient_groups(l1_scores, l2_scores, subcohorts)

    info('Writing output to {}'.format(output))

    patient_groups.info()

    patient_groups.to_csv(output, index=0)


if __name__ == '__main__':
    main()