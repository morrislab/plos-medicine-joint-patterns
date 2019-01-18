"""
Concatenates bootstrapped samples together.
"""

import feather
import pandas as pd
import tqdm

from click import *
from logging import *
from typing import *


@command()
@option(
    '--input',
    required=True,
    multiple=True,
    help='the Feather file(s) of samples to concatenate')
@option(
    '--output',
    required=True,
    help='the Feather file to write the concatenated data to')
def main(input: Tuple[str], output: str):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(),
            FileHandler('{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading and concatenating data')

    data = pd.concat(feather.read_dataframe(x) for x in tqdm.tqdm(input))

    info('Result: {}'.format(data.shape))

    # Write the output.

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':
    main()
