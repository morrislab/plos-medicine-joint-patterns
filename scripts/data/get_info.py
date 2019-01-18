"""
Extracts information about the data.
"""

import click
import pandas as pd
import yaml
import tqdm

from logging import *


@click.command()
@click.option(
    '--input',
    required=True,
    multiple=True,
    help='read input data from Excel files INPUT')
@click.option(
    '--output',
    required=True,
    help='output column information to YAML file OUTPUT')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Reading input data')

    data = {
        x: sorted(pd.read_excel(x).columns.tolist())
        for x in tqdm.tqdm(input)
    }

    info('Writing output')

    with open(output, 'w') as handle:

        yaml.dump(data, handle, default_flow_style=False)


if __name__ == '__main__':

    main()