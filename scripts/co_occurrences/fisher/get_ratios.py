"""
Calculates ratios of observed conditional proportions for sites.
"""

import pandas as pd
import tqdm

from click import *
from logging import *

SIDE_REGEX = r'_(left|right)$'

SIDE_EXTRACT_REGEX = SIDE_REGEX[1:]


def get_ratios(df: pd.DataFrame) -> pd.Series:
    """
    Calculates a ratio from the given data, defined as the proportion of same-
    side involvement over the proportion of opposite-side involvement.

    Args:
        df: table of conditional frequencies.
    """

    df = df.set_index('co_occurring_side')

    same_side = df['reference_side'].iloc[0]

    other_side = 'left' if same_side == 'right' else 'right'

    return pd.Series({
        'reference_root':
        df['reference_root'].iloc[0],
        'reference_side':
        same_side,
        'ratio':
        df.loc[same_side, 'conditional_probability'] /
        df.loc[other_side, 'conditional_probability']
    })


@command()
@option('--input', required=True, help='the CSV file to read proportions from')
@option('--output', required=True, help='the CSV file to write ratios to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading data')

    data = pd.read_feather(input)

    debug(f'Result: {data.shape}')

    # Drop reference sites that are not paired.

    info('Dropping unpaired sites')

    data = data.loc[data['reference_site'].str.contains(SIDE_REGEX)
                    & data['co_occurring_site'].str.contains(SIDE_REGEX)]

    for j in ['reference_site', 'co_occurring_site']:

        data[j] = data[j].astype(str)

    debug(f'Result: {data.shape}')

    # For each conditional site, determine the root site.

    info('Determining root sites')

    data['co_occurring_root'] = data['co_occurring_site'].str.replace(
        SIDE_REGEX, '')

    data['co_occurring_side'] = data['co_occurring_site'].str.extract(
        SIDE_EXTRACT_REGEX, expand=False)

    data['reference_root'] = data['reference_site'].str.replace(
        SIDE_REGEX, '')

    data['reference_side'] = data['reference_site'].str.extract(
        SIDE_EXTRACT_REGEX, expand=False)

    # Calculate ratios.

    info('Calculating ratios')

    tqdm.tqdm.pandas()

    ratios = data.groupby(['reference_site',
                           'co_occurring_root']).progress_apply(get_ratios)

    # Write the output.

    info('Writing output')

    ratios.to_csv(output)


if __name__ == '__main__':
    main()