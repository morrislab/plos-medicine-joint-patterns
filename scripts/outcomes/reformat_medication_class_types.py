"""
Reformats class types in medication summaries based on localization.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to read medication summary information from')
@option(
    '--output',
    required=True,
    help='the CSV file to write medication summary information to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading input')

    df = pd.read_csv(input)

    info('Result: {}'.format(df.shape))

    info('Reformatting class types')

    for x in ['_localized', '_diffuse']:

        df.loc[df['cls'].str.endswith(x), 'cls_type'] += x

    info('Writing output')

    df.to_csv(output, index=False)


if __name__ == '__main__':
    main()