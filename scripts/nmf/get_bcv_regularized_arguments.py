"""
Generates arguments to use for regularized cross-validation.
"""

import click
import feather

from logging import *
from tqdm import tqdm


@click.command()
@click.option(
    '--input', required=True, help='read input data from Feather file INPUT')
@click.option(
    '--min-k-output',
    required=True,
    help='output the minimum number of factors to text file MIN_K_OUTPUT')
@click.option(
    '--max-k-output',
    required=True,
    help='output the maximum number of factors to text file MIN_K_OUTPUT')
@click.option(
    '--multiplier',
    type=float,
    default=0.75,
    help='set the minimum rank to MULTIPLIER that of the maximum')
def main(input, min_k_output, max_k_output, multiplier):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(max_k_output), mode='w')
        ])

    info('Reading data from {}'.format(input))

    data = feather.read_dataframe(input)

    data.info()

    import IPython
    IPython.embed()
    raise Exception()

    info('Splitting data')

    for i in tqdm(data['visit_id'].dropna().astype(int).unique()):

        df = data.loc[data['visit_id'] == i].drop('visit_id', axis=1)

        df.to_csv('{}{:02d}.csv'.format(output_prefix, i), index=False)


if __name__ == '__main__':

    main()