"""
Outputs Circos data for the oligo-n and non-oligo-n sub-cohorts.
"""

import pandas as pd

from click import *
from logging import *
from typing import *


def get_oligo_non_oligos(l1_ix: pd.Index,
                         l2_ix: pd.Index) -> Tuple[pd.Index, pd.Index]:
    """
    Determines which patients are oligo-ns and non-oligo-ns from the given
    indices.

    Args:
        l1_ix: The level 1 NMF subject IDs.
        l2_ix: The level 2 NMF subject IDs.

    Returns:
        The oligo-n subject IDs and non-oligo-n subject IDs.
    """

    oligo_ids = l1_ix.difference(l2_ix)

    return oligo_ids, l2_ix


def filter_data(
        df_clusters: pd.DataFrame,
        df_diagnoses: pd.DataFrame,
        df_scores: pd.DataFrame,
        ids: pd.Index) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Filters the given patient group assignments, diagnoses, and scores to
    patients in the given index.

    Args:
        df_clusters: The patient group assignments.
        df_diagnoses: The diagnoses.
        df_scores: The scores.
        ids: The subject IDs to filter all data to.

    Returns:
        The filtered patient group assignments, diagnoses, and scores.
    """

    return df_clusters.loc[ids], df_diagnoses.loc[ids], df_scores.loc[ids]


@command()
@option(
    '--cluster-input',
    required=True,
    metavar='CLUSTER-INPUT',
    help='load patient group assignments from CSV file CLUSTER-INPUT')
@option(
    '--diagnosis-input',
    required=True,
    metavar='DIAGNOSIS-INPUT',
    help='load diagnoses from CSV file DIAGNOSIS-INPUT')
@option(
    '--subcohort-input',
    required=True,
    metavar='SUBCOHORT-INPUT',
    help='load subcohort assignments from CSV file SUBCOHORT-INPUT')
@option(
    '--l1-score-input',
    required=True,
    metavar='L1-SCORE-INPUT',
    help=('load level 1 NMF scores for oligo-n patients from CSV file '
          'L1-SCORE-INPUT'))
@option(
    '--l2-score-input',
    required=True,
    metavar='L2-SCORE-INPUT',
    help=('load level 2 NMF scores for non-oligo-n patients from CSV file '
          'L2-SCORE-INPUT'))
@option(
    '--localized-oligo-cluster-output',
    required=True,
    metavar='LOCALIZED-OLIGO-CLUSTER-OUTPUT',
    help=('output patient group assignments for localized oligo-n patients to '
          'CSV file LOCALIZED-OLIGO-CLUSTER-OUTPUT'))
@option(
    '--localized-oligo-diagnosis-output',
    required=True,
    metavar='LOCALIZED-OLIGO-DIAGNOSIS-OUTPUT',
    help=('output diagnoses for localized oligo-n patients to CSV file '
          'LOCALIZED-OLIGO-DIAGNOSIS-OUTPUT'))
@option(
    '--localized-oligo-score-output',
    required=True,
    metavar='LOCALIZED-OLIGO-SCORE-OUTPUT',
    help=('output scores for localized oligo-n patients to CSV file '
          'LOCALIZED-OLIGO-SCORE-OUTPUT'))
@option(
    '--diffuse-oligo-cluster-output',
    required=True,
    metavar='DIFFUSE-OLIGO-CLUSTER-OUTPUT',
    help=('output patient group assignments for diffuse oligo-n patients to '
          'CSV file DIFFUSE-OLIGO-CLUSTER-OUTPUT'))
@option(
    '--diffuse-oligo-diagnosis-output',
    required=True,
    metavar='DIFFUSE-OLIGO-DIAGNOSIS-OUTPUT',
    help=('output diagnoses for diffuse oligo-n patients to CSV file '
          'DIFFUSE-OLIGO-DIAGNOSIS-OUTPUT'))
@option(
    '--diffuse-oligo-score-output',
    required=True,
    metavar='DIFFUSE-OLIGO-SCORE-OUTPUT',
    help=('output scores for diffuse oligo-n patients to CSV file '
          'DIFFUSE-OLIGO-SCORE-OUTPUT'))
@option(
    '--non-oligo-cluster-output',
    required=True,
    metavar='NON-LOCALIZED-OLIGO-CLUSTER-OUTPUT',
    help=('output patient group assignments for non-oligo-n patients to CSV '
          'file NON-LOCALIZED-OLIGO-CLUSTER-OUTPUT'))
@option(
    '--non-oligo-diagnosis-output',
    required=True,
    metavar='NON-LOCALIZED-OLIGO-DIAGNOSIS-OUTPUT',
    help=('output diagnoses for non-oligo-n patients to CSV file '
          'NON-LOCALIZED-OLIGO-DIAGNOSIS-OUTPUT'))
@option(
    '--non-oligo-score-output',
    required=True,
    metavar='NON-LOCALIZED-OLIGO-SCORE-OUTPUT',
    help=('output scores for non-oligo-n patients to CSV file '
          'NON-LOCALIZED-OLIGO-SCORE-OUTPUT'))
def main(cluster_input, diagnosis_input, subcohort_input, l1_score_input,
         l2_score_input, localized_oligo_cluster_output,
         localized_oligo_diagnosis_output, localized_oligo_score_output,
         diffuse_oligo_cluster_output, diffuse_oligo_diagnosis_output,
         diffuse_oligo_score_output, non_oligo_cluster_output,
         non_oligo_diagnosis_output, non_oligo_score_output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(localized_oligo_cluster_output))
        ])

    info('Loading patient groups')

    clusters = pd.read_csv(cluster_input, index_col=0)

    clusters.info()

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col=0)

    diagnoses.info()

    info('Loading subcohorts')

    subcohorts = pd.read_csv(subcohort_input, index_col=0, squeeze=True)

    info('Loading level 1 scores')

    l1_scores = pd.read_csv(l1_score_input, index_col=0)

    l1_scores.info()

    info('Loading level 2 scores')

    l2_scores = pd.read_csv(l2_score_input, index_col=0)

    l2_scores.info()

    # Filter the sub-cohort data.

    info('Filtering subcohort data')

    subcohorts = subcohorts.loc[l1_scores.index | l2_scores.index].query(
        'visit_id == 1').drop(
            'visit_id', axis=1).squeeze()

    info('Obtaining data for subcohorts')

    (localized_oligo_clusters, localized_oligo_diagnoses,
     localized_oligo_scores) = filter_data(
         clusters, diagnoses, l1_scores,
         subcohorts.loc[subcohorts == 'localized_oligo'].index)

    (diffuse_oligo_clusters, diffuse_oligo_diagnoses,
     diffuse_oligo_scores) = filter_data(
         clusters, diagnoses, l2_scores,
         subcohorts.loc[subcohorts == 'diffuse_oligo'].index)

    non_oligo_clusters, non_oligo_diagnoses, non_oligo_scores = filter_data(
        clusters, diagnoses, l2_scores,
        subcohorts.loc[subcohorts == 'non_oligo'].index)

    info('Writing data')

    localized_oligo_clusters.to_csv(localized_oligo_cluster_output)

    localized_oligo_diagnoses.to_csv(localized_oligo_diagnosis_output)

    localized_oligo_scores.to_csv(localized_oligo_score_output)

    diffuse_oligo_clusters.to_csv(diffuse_oligo_cluster_output)

    diffuse_oligo_diagnoses.to_csv(diffuse_oligo_diagnosis_output)

    diffuse_oligo_scores.to_csv(diffuse_oligo_score_output)

    non_oligo_clusters.to_csv(non_oligo_cluster_output)

    non_oligo_diagnoses.to_csv(non_oligo_diagnosis_output)

    non_oligo_scores.to_csv(non_oligo_score_output)


if __name__ == '__main__':

    main()