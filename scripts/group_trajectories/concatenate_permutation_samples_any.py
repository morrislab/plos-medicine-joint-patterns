"""
Concatenates results from permutation tests.
"""

import feather
import pandas as pd
import tqdm

from click import *
from logging import *


@command()
@option(
    '--input',
    required=True,
    multiple=True,
    help='load input samples from Feather files INPUTs')
@option(
    '--output',
    required=True,
    help='output concatenated samples to Feather file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Concatenating samples')

    samples = (feather.read_dataframe(x) for x in tqdm.tqdm(input))

    result = pd.concat(samples)

    info('Formatting output')

    for j in ['seed', 'source', 'target']:

        result[j] = result[j].astype('category')

    info('Writing output')

    result.info()

    feather.write_dataframe(result, output)


if __name__ == '__main__':
    main()