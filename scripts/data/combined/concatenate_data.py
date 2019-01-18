"""
Concatenates the given site involvement data together.
"""

import feather
import pandas as pd

from click import *
from logging import *


def load_data(path: str) -> pd.DataFrame:
    """
    Loads data from the given path.

    Args:
        path: The path to load data from.

    Returns:
        The loaded data.
    """

    info('Loading {}'.format(path))

    path_lower = path.lower()

    result = pd.read_csv(
        path, index_col='subject_id') if path_lower.endswith(
            '.csv') else feather.read_dataframe(path).set_index('subject_id')

    info('Result: {}'.format(result.shape))

    return result


@command()
@option(
    '--input',
    required=True,
    multiple=True,
    help='the CSV and Feather files to load site involvements from')
@option(
    '--output',
    required=True,
    help='the CSV file to output concatenated site involvements to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    gen_sites = (load_data(path) for path in input)

    # Concatenate the data.

    info('Concatenating data...')

    df_concatenated = pd.concat(gen_sites)

    info('Result: {}'.format(df_concatenated.shape))

    # Write the output.

    info('Writing output')

    df_concatenated.to_csv(output)


if __name__ == '__main__':
    main()