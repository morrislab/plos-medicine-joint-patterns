"""
Summarizes medications at future time points.
"""

import feather
import pandas as pd

from click import *
from logging import *


def summarize_medications(df: pd.DataFrame, j: str) -> pd.DataFrame:
    """
    Summarizes medications.

    Args:
        df: The table to summarize medications from.
        j: The column to use as the classification column.

    Returns:
        Counts.
    """

    y = df.groupby(
        ['visit_id', 'medication', j, 'status'])['subject_id'].agg('count')

    y.name = 'count'

    y = y.reset_index()

    y.rename(columns={j: 'cls'}, inplace=True)

    y['cls_type'] = j

    # Calculate proportions.

    y['proportion'] = y.groupby(['visit_id', 'medication', 'cls'])[
        'count'].apply(lambda x: x / x.sum())

    return y


@command()
@option(
    '--medication-input',
    required=True,
    help='the Feather file to read medication information from')
@option(
    '--joint-injection-input',
    required=True,
    help='the Feather file to read joint injection information from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--output',
    required=True,
    help='the CSV file to write summary information to')
@option(
    '--visit',
    type=int,
    multiple=True,
    help='visits to restrict the data to (multiples permitted)')
def main(medication_input, joint_injection_input, cluster_input,
         diagnosis_input, output, visit):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading medications')

    medications = feather.read_dataframe(medication_input)

    medications.dropna(subset=['visit_id'], inplace=True)

    medications['visit_id'] = medications['visit_id'].astype(int)

    info('Result: {}'.format(medications.shape))

    info('Loading joint injections')

    joint_injections = feather.read_dataframe(joint_injection_input)

    joint_injections.dropna(subset=['visit_id'], inplace=True)

    joint_injections['visit_id'] = joint_injections['visit_id'].astype(int)

    info('Result: {}'.format(joint_injections.shape))

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0)

    info('Result: {}'.format(clusters.shape))

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col=0)[['diagnosis']]

    info('Result: {}'.format(diagnoses.shape))

    # Filter the diagnoses.

    info('Filtering diagnoses')

    diagnoses = diagnoses.loc[clusters.index]

    # If visits have been defined, filter down to them.

    if visit is not None:

        info('Filtering visits')

        medications = medications.loc[medications['visit_id'].isin(visit)]

        joint_injections = joint_injections.loc[joint_injections['visit_id']
                                                .isin(visit)]

    # Filter down to patients of interest.

    info('Filtering medications to patients')

    medications = medications.loc[medications['subject_id'].isin(
        clusters.index)]

    joint_injections = joint_injections.loc[joint_injections['subject_id']
                                            .isin(clusters.index)]

    # Melt the medications.

    info('Melting medications')

    medications = pd.melt(
        medications,
        id_vars=['subject_id', 'visit_id'],
        var_name='medication',
        value_name='status')

    medications['medication'] = medications['medication'].str.replace(
        '_status$', '')

    medications['status'] = ~(medications['status'].isin(['NONE', 'NEW']))

    # Convert joint injection statuses.
    #
    # Patients been administered a joint injection prior to a visit if their
    # injection status is not `NONE` and the maximum number of days elapsed
    # since that injection is positive.

    info('Calculating joint injection statuses')

    joint_injections['status'] = (
        joint_injections['injection_status'] != 'NONE') & (
            (joint_injections['days_max'] > 0) |
            joint_injections['days_max'].isnull())

    # Concatenate the medications with joint injections.

    info('Merging medications with joint injections')

    joint_injections['medication'] = 'joint_injection'

    df_concat = pd.concat(
        x[['subject_id', 'visit_id', 'medication', 'status']]
        for x in [medications, joint_injections])

    # Merge in the clusters and diangoses.

    info('Merging clusters and diagnoses')

    df_merged = df_concat.merge(
        clusters, left_on='subject_id', right_index=True).merge(
            diagnoses, left_on='subject_id', right_index=True)

    # Summarize the medication data.

    info('Summarizing medications')

    summary_clusters = summarize_medications(df_merged, 'classification')

    summary_diagnoses = summarize_medications(df_merged, 'diagnosis')

    summaries = pd.concat([summary_clusters, summary_diagnoses])

    # Write the output.

    info('Writing output')

    summaries.to_csv(output, index=False)


if __name__ == '__main__':
    main()