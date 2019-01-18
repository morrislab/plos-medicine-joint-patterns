"""
Combines NMF scores into one large table.
"""

import pandas as pd
import string

from click import *
from logging import *


@command()
@option(
    '--l1-score-input',
    required=True,
    metavar='INPUT',
    help='read level 1 NMF scores from CSV file INPUT')
@option(
    '--l2-score-input',
    required=True,
    metavar='INPUT',
    help='read level 2 NMF scores from CSV file INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='write merged scores to CSV file OUTPUT')
def main(l1_score_input, l2_score_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading level 1 scores from {}'.format(l1_score_input))

    l1_scores = pd.read_csv(l1_score_input, index_col=0)

    l1_scores.info()

    info('Loading level 2 scores from {}'.format(l2_score_input))

    l2_scores = pd.read_csv(l2_score_input, index_col=0)

    l2_scores.info()

    # Reformat the column names.

    info('Reformatting column names')

    l1_scores.columns = [
        'factor_l1_{:02d}'.format(int(x)) for x in l1_scores.columns
    ]

    l2_scores.columns = [
        'factor_l2_{}'.format(string.ascii_lowercase[int(x) - 1])
        for x in l2_scores.columns
    ]

    # Merge the data.

    info('Merging data')

    merged_data = l1_scores.merge(
        l2_scores, left_index=True, right_index=True, how='outer').fillna(0.)

    # Write the output.

    info('Writing output')

    merged_data.info()

    merged_data.to_csv(output)


if __name__ == '__main__':
    main()