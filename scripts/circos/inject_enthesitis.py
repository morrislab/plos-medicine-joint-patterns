"""
Injects enthesitis statuses into the given scores.
"""

import feather
import numpy as np
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--score-input',
    required=True,
    metavar='SCORE-INPUT',
    help='read scores from CSV file SCORE-INPUT')
@option(
    '--enthesitis-input',
    required=True,
    metavar='ENTHESITIS-INPUT',
    help='read enthesitis data from Feather file ENTHESITIS-INPUT')
@option(
    '--output',
    required=True,
    metavar='OUTPUT',
    help='output modified scores to CSV file OUTPUT')
def main(score_input, enthesitis_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading scores')

    scores = pd.read_csv(score_input, index_col=0)

    scores.info()

    info('Loading enthesitis information')

    enthesitis = feather.read_dataframe(enthesitis_input)

    enthesitis.info()

    enthesitis = enthesitis.query('visit_id == 1').drop(
        'visit_id', axis=1).set_index('subject_id')

    info('Calculating number of sites involved')

    num_entheses = enthesitis.sum(axis=1)

    has_enthesitis = (num_entheses > 0).astype(int)

    info('Inserting enthesitis information')

    scores.insert(0, 0, has_enthesitis.loc[scores.index].fillna(0.))

    scores.columns = np.arange(scores.shape[1]) + 1

    info('Writing output')

    scores.to_csv(output)


if __name__ == '__main__':
    main()