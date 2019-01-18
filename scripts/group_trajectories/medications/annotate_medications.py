"""
Annotates medication data with baseline classifications and non-zero joint
involvement status.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the Feather file to read input data from')
@option(
    '--cluster-input',
    required=True,
    help='the CSV file to read classifications from')
@option(
    '--output', required=True, help='the Feather file to write output data to')
def main(data_input: str, cluster_input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading data')

    data = pd.read_feather(data_input)

    debug(f'Result: {data.shape}')

    info('Loading classifications')

    cls = pd.read_csv(cluster_input)

    debug(f'Result: {cls.shape}')

    info('Obtaining baseline classifications')

    baseline_classifications = cls.query(
        'visit_id == 1').set_index('subject_id')[['classification']].rename(
            columns={'classification': 'baseline_classification'})

    info('Obtaining zero joint statuses')

    zero_joint_statuses = cls.query('visit_id > 1').set_index(
        ['subject_id', 'visit_id'])['classification'] == '0'

    zero_joint_statuses.name = 'zero_joints'

    zero_joint_statuses = zero_joint_statuses.to_frame()

    info('Merging baseline classifications')

    data = data.set_index(['subject_id']).join(
        baseline_classifications, how='inner').reset_index()

    data['baseline_classification'] = data['baseline_classification'].astype(
        'category')

    info('Merging zero joint statuses')

    data = data.set_index(['subject_id', 'visit_id']).join(
        zero_joint_statuses, how='inner').reset_index()

    info('Writing output')

    data.to_feather(output)


if __name__ == '__main__':
    main()