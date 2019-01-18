"""
Transforms the extracted data.
"""

import click
import feather
import numpy as np
import pandas as pd
import re
import tqdm
import yaml

from logging import *
from typing import *


def yes_no(x: str) -> float:
    """
    Transforms a yes/no value to a numeric value.

    Args:
        x: The value to transform.

    Returns:
        The transformed value.

    Raises:
        ValueError: When the value cannot be translated.
    """

    if pd.isnull(x) or x == '':

        return np.nan

    y = x.lower()

    if y in ['y', 'pos']:

        return 1.

    elif y.startswith('n'):

        return 0.

    raise ValueError('cannot translate yes/no value: {!r}'.format(x))


def float_(x: str) -> float:
    """
    Transforms what should be a float value to a numeric value.

    Args:
        x: The value to transform.

    Returns:
        The transformed value.

    Raises:
        ValueError: When the value cannot be translated.
    """

    if pd.isnull(x):

        return np.nan

    try:

        return float(x)

    except ValueError:

        y = x.lower()

        if y.startswith('neg'):

            return 0.

        m = re.match(r'^(\d+)', y)

        if m is not None:

            return float(m.group(1))

        m = re.match(r'^<(.+)$', y)

        if m is not None:

            return float(m.group(1)) - 1e-6

        m = re.match(r'^>(.+)$', y)

        if m is not None:

            return float(m.group(1)) + 1e-6

        raise ValueError('cannot parse float value: {!r}'.format(x))


def sex_female(x: str) -> float:
    """
    Transforms a sex into a numeric value denoting whether a patient is
    female.

    Args:
        x: The value to transform.

    Returns:
        The transformed value.

    Raises:
        ValueError: When the value cannot be translated.
    """

    if pd.isnull(x):

        return np.nan

    y = x.lower()

    if y.startswith('f'):

        return 1.

    elif y.startswith('m'):

        return 0.

    raise ValueError('cannot translate sex: {!r}'.format(x))


TYPE_MAP = {'yes_no': yes_no, 'float': float_, 'sex': sex_female}


@click.command()
@click.option(
    '--type-map-input',
    type=click.File('rU'),
    required=True,
    help='read a type map from TYPE_MAP_INPUT')
@click.option(
    '--data-input',
    required=True,
    help='read input data from Feather file INPUT')
@click.option(
    '--output', required=True, help='output results to Feather file OUTPUT')
def main(type_map_input, data_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading type map')

    type_map = yaml.load(type_map_input)

    info('Reading data')

    data = feather.read_dataframe(data_input)

    data.info()

    info('Verifying columns')

    bad_columns = set(type_map.keys()) - set(data.columns)

    if bad_columns:

        raise KeyError('columns not found in data: {!r}'.format(
            sorted(bad_columns)))

    info('Applying transformations')

    for k, v in tqdm.tqdm(type_map.items()):

        data[k] = data[k].apply(TYPE_MAP[v]).astype(float)

    # Remove missing values.

    info('Removing missing values')

    for j in data.columns.difference(['subject_id', 'visit_id']):

        data.loc[data[j] >= 8888, j] = np.nan

    # Write the output data.

    info('Writing data')

    data.info()

    feather.write_dataframe(data, output)


if __name__ == '__main__':

    main()