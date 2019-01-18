"""
Obtains cluster assignments from the nested NMF oligo-n approach.
"""

import pandas as pd
import string

from click import *
from logging import *


@command()
@option(
    '--l1-score-input',
    required=True,
    metavar='L1-SCORE-INPUT',
    help='load level 1 scores for oligo-ns from CSV file L1-SCORE-INPUT')
@option(
    '--l2-score-input',
    required=True,
    metavar='L2-SCORE-INPUT',
    help='load level 2 scores for oligo-ns from CSV file L2-SCORE-INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output cluster assignments to CSV file OUTPUT')
def main(l1_score_input, l2_score_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading level 1 scores')

    l1_scores = pd.read_csv(l1_score_input, index_col=0)

    l1_scores.info()

    info('Loading level 2 scores')

    l2_scores = pd.read_csv(l2_score_input, index_col=0)

    l2_scores.info()

    info('Renaming factors')

    l1_scores.columns = (l1_scores.columns.astype(int)).map('{:02d}'.format)

    l2_scores.columns = (l2_scores.columns.astype(int) - 1
                         ).map(string.ascii_uppercase.__getitem__)

    info('Assigning patient groups')

    l1_clusters = l1_scores.apply(
        pd.Series.argmax, axis=1).to_frame().rename(
            columns={0: 'classification'})

    l2_clusters = l2_scores.apply(
        pd.Series.argmax, axis=1).to_frame().rename(
            columns={0: 'classification'})

    info('Concatenating assignments')

    clusters = pd.concat([l1_clusters, l2_clusters])

    info('Writing output to {}'.format(output))

    clusters.to_csv(output)


if __name__ == '__main__':

    main()