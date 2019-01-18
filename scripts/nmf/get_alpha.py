"""
Obtains the optimal value of alpha.
"""

import click
import feather

from logging import *


@click.command()
@click.option(
    '--input',
    required=True,
    help='read samples from Feather file INPUT')
@click.option(
    '--output',
    required=True,
    help='write the alpha parameter to text file OUTPUT')
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

    g = samples.groupby('alpha')

    means = g['q2'].mean().sort_index(ascending=False)

    ses = (g['q2'].std() / (g['q2'].count()**0.5)).sort_index(ascending=False)

    info('Calculating Q2 threshold')

    alpha_zero = means.argmax()

    threshold = means.loc[alpha_zero] - ses.loc[alpha_zero]

    alpha_reduced = (means >= threshold).argmax()

    info('Reduced alpha: {}'.format(alpha_reduced))

    info('Writing parameter')

    with open(output, 'w') as handle:

        handle.write(str(alpha_reduced))


if __name__ == '__main__':

    main()