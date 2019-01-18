"""
Summarizes deltas.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option('--input', required=True, help='the CSV file to read deltas from')
@option('--output', required=True, help='the CSV file to write summaries to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(input)

    info('Result: {}'.format(data.shape))

    # Calculate summaries.

    info('Calculating summaries')

    mean_offdiagonal = data.query(
        'reference_site_root != co_occurring_site_root')['delta'].mean()

    mean_diagonal = data.query(
        'reference_site_root == co_occurring_site_root')['delta'].mean()

    # Compile the summaries.

    info('Compiling summaries')

    summary = pd.DataFrame({
        'diagonal': ['off_diagonal', 'on_diagonal'],
        'mean': [mean_offdiagonal, mean_diagonal]
    })

    # Write the output.

    info('Writing output')

    summary.to_csv(output, index=False)


if __name__ == '__main__':
    main()