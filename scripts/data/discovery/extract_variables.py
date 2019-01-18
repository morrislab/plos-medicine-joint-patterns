"""
Extracts variables from the data.
"""

import click
import feather
import functools as ft
import joblib as jl
import pandas as pd
import tqdm
import yaml

from collections import namedtuple
from logging import *
from typing import *

Data = namedtuple('Data', 'data has_visit_id')


def load_data(path: str, field_map: Dict[str, str]) -> Data:
    """
    Loads data from the given path, selecting data and transforming column
    names according to the given field map.

    Args:
        path: The path to load the data from.
        field_map: A mapping of input fields to output fields.

    Returns:
        A table of extracted variables and a flag denoting whether the table
        has a visit ID.

    Raises:
        KeyError: If no variables were extracted.
    """

    data = pd.read_excel(path)

    relevant_columns = data.columns.intersection(list(field_map.values()))

    if relevant_columns.size < 1:

        raise KeyError('no relevant columns identified in {}'.format(path))

    columns_to_extract = ['SUBJECT_ID']

    if 'VISIT_ID' in data.columns:

        columns_to_extract += ['VISIT_ID']

    columns_to_extract += relevant_columns.tolist()

    data = data[columns_to_extract]

    new_field_map = {v: k for k, v in field_map.items()}

    new_field_map.update({'SUBJECT_ID': 'subject_id', 'VISIT_ID': 'visit_id'})

    data.rename(columns=new_field_map, inplace=True)

    return Data(data, 'visit_id' in data)


@click.command()
@click.option(
    '--field-map-input',
    type=click.File('rU'),
    required=True,
    help='read a field map from FIELD_MAP_INPUT')
@click.option(
    '--data-input',
    required=True,
    multiple=True,
    help='read input data from Excel files INPUT')
@click.option(
    '--output', required=True, help='output variables to Feather file OUTPUT')
def main(field_map_input, data_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading field map')

    field_map = yaml.load(field_map_input)

    info('Reading data')

    data = jl.Parallel(n_jobs=-1)(jl.delayed(load_data)(x, field_map)
                                  for x in tqdm.tqdm(data_input))

    info('Verifying extracted columns')

    observed_columns = ft.reduce(pd.Index.union, (x.data.columns
                                                  for x in data))

    missing_columns = set(field_map.keys()) - set(observed_columns)

    if missing_columns:

        raise KeyError('unable to extract columns: {!r}'.format(
            sorted(missing_columns)))

    info('Merging data with visit information')

    visit_data = (x.data.set_index(['subject_id', 'visit_id']) for x in data
                  if x.has_visit_id)

    visit_data = ft.reduce(
        ft.partial(
            pd.DataFrame.join, how='outer'), visit_data)

    info('Merging data with visitless information')

    visitless_data = (x.data.set_index('subject_id') for x in data
                      if not x.has_visit_id)

    visitless_data = ft.reduce(
        ft.partial(
            pd.DataFrame.join, how='outer'), visitless_data)

    info('Merging data')

    merged_data = visit_data.reset_index().set_index('subject_id').join(
        visitless_data, how='outer').reset_index()

    info('Reducing data to categories')

    for j in merged_data.columns.difference(['subject_id', 'visit_id']):

        if merged_data[j].dtype == object:

            warning('Column {!r} contains non-numerical values'.format(j))

            merged_data[j] = merged_data[j].astype('category')

    info('Writing data')

    merged_data.info()

    feather.write_dataframe(merged_data, output)


if __name__ == '__main__':

    main()