"""
Obtains the optimal value of k.
"""

import click
import feather

from logging import *


@click.command()
@click.option(
    '--input', required=True, help='read samples from Feather file INPUT')
@click.option(
    '--output', required=True, help='write the value of k to text file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading input data')

    samples = feather.read_dataframe(input)

    samples.info()

    info('Pruning bad runs')

    samples = samples.loc[samples['q2'] > -1.]

    samples.info()

    info('Calculating statistics')

    g = samples.groupby('k')

    means = g['q2'].mean()

    info('Calculating Q2 threshold')

    k_max = means.argmax()

    info('k with highest Q2: {}'.format(k_max))

    info('Writing parameter')

    with open(output, 'w') as handle:

        handle.write(str(k_max))


if __name__ == '__main__':

    main()