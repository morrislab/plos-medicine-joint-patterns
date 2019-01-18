"""
Extracts site information from the BBOP data.
"""

import feather
import pandas as pd
import re

from click import *
from logging import *
from typing import *

SITE_MAP = {
    'CERVICAL': 'cervical_spine',
    'MPC': 'mcp',
    'SI': 'sacroiliac',
    'TOE': 'toe_ip',
    'IP': 'pip1'
}


def process_column_name(x: str) -> str:
    """
    Processes a column name.

    Args:
        x: The name to process.

    Returns;
        The processed name.
    """

    y = re.sub(r'^JOINT_', '', x)

    side_match = re.match(r'^([LR])', y)

    side = None

    if side_match:

        s = side_match.group(1)

        side = 'left' if s == 'L' else 'right'

        y = y[1:]

    parts_match = re.match(r'^([A-Z]+)(\d)?$', y)

    site, number = parts_match.groups()

    if site in SITE_MAP:

        site = SITE_MAP[site]

    else:

        site = site.lower()

    return '{}{}{}'.format(site, number or '', '_{}'.format(side)
                           if side is not None else '')


def get_column_map(columns: Iterable[str]) -> Dict[str, str]:
    """
    Generates a column map for the given columns.

    Args:
        columns: Columns to map.

    Returns:
        A mapping of old names to new names.
    """

    result = {'PatientID': 'subject_id'}

    result.update(
        {j: process_column_name(j)
         for j in columns if j != 'PatientID'})

    return result


@command()
@option(
    '--input',
    required=True,
    help='the CSV file to load site information from')
@option(
    '--output',
    required=True,
    help='the Feather file to output extracted site information to')
def main(input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    df = pd.read_csv(input)

    info('Result: {}'.format(df.shape))

    # Filter to baseline visit and BBOP cohort 1.

    info('Filtering to baseline and BBOP cohort 1')

    df = df.query('VisitNumber == 1 and BBOPcohort == 1')

    # Select columns.

    info('Selecting columns')

    cols_to_select = ['PatientID'] + df.columns[df.columns.str.contains(
        r'^JOINT_')].tolist()

    df_selected = df[cols_to_select].copy()

    # Rename the columns.

    info('Renaming columns')

    col_map = get_column_map(df_selected.columns)

    df_selected.rename(columns=col_map, inplace=True)

    # Reformat values.

    info('Reformatting values')

    df_selected = df_selected.apply(
        lambda x: x.str.replace(',', '').astype(int))

    # Set the index to subject IDs.

    info('Setting index')

    df_selected.set_index('subject_id', inplace=True)

    # Drop patients completely missing data.

    info('Dropping patients completely missing data')

    df_selected = df_selected.loc[df_selected.apply(
        lambda x: x.unique()[0] != 9999, axis=1)]

    # Fix the data.

    info('Fixing joint involvement statuses')

    df_selected *= -1

    # Write the data.

    info('Writing data')

    feather.write_dataframe(df_selected.reset_index(), output)


if __name__ == '__main__':
    main()