"""
Merges permutation test samples together.
"""

import feather
import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    multiple=True,
    help='the Feather file to load samples from (multiple allowed)')
@option('--output', required=True, help='the Feather file to write output to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Concatenate away.

    info('Concatenating data')

    data = (feather.read_dataframe(x) for x in input)

    concatenated = pd.concat(data)

    # Write the data.

    info('Writing data')

    feather.write_dataframe(concatenated, output)


if __name__ == '__main__':
    main()