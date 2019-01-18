"""
Splits clusters by localization.
"""

import pandas as pd
import pathlib

from click import *
from logging import *


@command()
@option(
    '--input', required=True, help='the CSV file to read localizations from')
@option(
    '--output-dir',
    required=True,
    help='the directory to write output data to')
def main(input: str, output_dir: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler(
                str(pathlib.Path(output_dir) / 'clusters.log'), mode='w')
        ])

    output_dir = pathlib.Path(output_dir)

    # Load the data.

    info('Loading localizations')

    localizations = pd.read_csv(input, index_col=0)

    info('Result: {}'.format(localizations.shape))

    # Generate the splits.

    info('Generating splits')

    g = localizations.groupby('localization')

    split_clusters = {
        k: g.get_group(k).drop(['localization', 'threshold'], axis=1)
        for k in g.groups
    }

    # Write the output.

    info('Writing output')

    for k in split_clusters.keys():

        split_clusters[k].to_csv(str(output_dir / f'{k}.csv'))


if __name__ == '__main__':
    main()
