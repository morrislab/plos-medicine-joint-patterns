"""
Splits scores by localization.
"""

import pandas as pd
import pathlib

from click import *
from logging import *


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to read site involvements from')
@option(
    '--localization-input',
    required=True,
    help='the CSV file to read localizations from')
@option(
    '--output-dir',
    required=True,
    help='the directory to write output data to')
def main(data_input: str, localization_input: str, output_dir: str):

    basicConfig(level=DEBUG)

    output_dir = pathlib.Path(output_dir)

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input, index_col=0)

    debug(f'Result: {data.shape}')

    info('Loading localizations')

    localizations = pd.read_csv(localization_input, index_col=0)

    debug(f'Result: {localizations.shape}')

    # Generate the splits.

    info('Generating splits')

    g = localizations.groupby('localization')

    split_clusters = {
        k: g.get_group(k).drop(['localization', 'threshold'], axis=1)
        for k in g.groups
    }

    split_data = {k: data.loc[v.index] for k, v in split_clusters.items()}

    # Write the output.

    info('Writing output')

    for k in split_clusters.keys():

        split_data[k].to_csv(str(output_dir / f'{k}.csv'))


if __name__ == '__main__':
    main()
