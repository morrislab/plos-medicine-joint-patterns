"""
Calculates the composition of patient groups and ILAR classifications.
"""

import pandas as pd

from click import *
from logging import *


def get_proportions(x: pd.Series) -> pd.Series:
    """
    Calculates proportions of patients assigned in the classification given by
    the series who fall into other classifications.

    Args:
        x: Numbers of patients.

    Returns:
        Proportions.
    """

    return x / x.sum()


@command()
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read cluster assignments from')
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option(
    '--output', required=True, help='the CSV file to output proportions to')
def main(cluster_input, diagnosis_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col='subject_id')

    info('Result: {}'.format(clusters.shape))

    info('Loading diagnoses')

    diagnoses = pd.read_csv(
        diagnosis_input, index_col='subject_id')[['diagnosis']]

    info('Result: {}'.format(diagnoses.shape))

    # Join the classifications.

    info('Joining classifications')

    classifications = clusters.join(diagnoses, how='inner')

    # Calculate proportions.

    info('Calculating proportions')

    tab = pd.crosstab(classifications['diagnosis'],
                      classifications['classification'])

    diagnosis_compositions = tab.apply(get_proportions, axis=1)

    cluster_compositions = tab.apply(get_proportions, axis=0).T

    # Melt and combine the data.

    info('Combining data')

    diagnosis_compositions_melted = diagnosis_compositions.reset_index().melt(
        id_vars='diagnosis',
        var_name='target_classification',
        value_name='proportion').rename(
            columns={'diagnosis': 'source_classification'})

    cluster_compositions_melted = cluster_compositions.reset_index().melt(
        id_vars='classification',
        var_name='target_classification',
        value_name='proportion').rename(
            columns={'classification': 'source_classification'})

    compositions = pd.concat(
        [diagnosis_compositions_melted, cluster_compositions_melted])

    # Write the output.

    info('Writing output')

    compositions.to_csv(output, index=False)


if __name__ == '__main__':
    main()