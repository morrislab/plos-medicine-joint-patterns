"""Extract medication statuses from BBOP.
"""

import feather
import pandas as pd
import re

from click import *
from logging import *


def preprocess_start_date(x: str) -> str:
    """
    Fixes a start date.

    Contains special handling for cases such as `5-Aug` or `Aug-05`, which
    should be August 2005.

    Also handles a special case where the date is mistyped as `nnnn/nnnn`,
    which should be `nnnn/nn/nn`.

    Args:
        X: A start date.

    Returns:
        The fixed start date.
    """

    if isinstance(x, str):

        matches = re.match(r'^(\d+)-([A-Za-z]+)$', x)

        if matches:

            return '{}-{}'.format(2000 + int(matches.group(1)),
                                  matches.group(2))

        matches = re.match(r'^([A-Za-z]+)-(\d+)$', x)

        if matches:

            return '{}-{}'.format(2000 + int(matches.group(2)),
                                  matches.group(1))

        matches = re.match(r'^(\d{4})\/(\d{4})$', x)

        if matches:

            return '{}/{}/{}'.format(
                matches.group(1), matches.group(2)[:2], matches.group(2)[2:])

    return x


def convert_start_dates(x: pd.Series) -> pd.Series:
    """
    Converts start dates to datetieme objects.

    Args:
        x: Unconverted start dates.

    Returns:
        Converted start dates.
    """

    preprocessed = x.apply(preprocess_start_date)

    return pd.to_datetime(preprocessed)


def melt_drug_histories(df: pd.DataFrame, j: int) -> pd.DataFrame:
    """
    Obtains drug histories for the jth drug.

    Args:
        df: Unformatted drug histories.
        j: Drug number.

    Returns:
        Drug histories for the jth drug.
    """

    result = df[[
        'PatientID', 'VISITDATE', 'DRUG_{}'.format(j), 'START_DATE{}'.format(j)
    ]]

    result.columns = ['subject_id', 'visit_date', 'drug', 'start_date']

    result = result.loc[result['drug'].notnull()]

    result['drug'] = result['drug'].astype('int')

    result['start_date'] = convert_start_dates(result['start_date'])

    return result


def reformat_drug_histories(df: pd.DataFrame) -> pd.DataFrame:
    """
    Reformats drug histories.

    Args:
        df: Unformatted drug histories.

    Returns:
        Reformatted drug histories.
    """

    # Determine how many drug entries we have.

    all_j = df.columns.str.extract(r'(\d+)').dropna().unique().astype(int)

    # Extract entries for all drugs.

    reformatted = pd.concat(melt_drug_histories(df, j) for j in all_j)

    # Filter down to cases where the start date is before the visit date or is
    # missing.

    reformatted = reformatted.loc[reformatted['start_date'].isnull() | (
        reformatted['start_date'] < reformatted['visit_date'])]

    return reformatted


def melt_drug_changes(df: pd.DataFrame, j: int) -> pd.DataFrame:
    """
    Obtains drug changes for the jth drug.

    Args:
        df: Unformatted drug changes.
        j: Drug number.

    Returns:
        Drug changes for the jth drug.
    """

    result = df[
        ['PatientID', 'C_DRUG_{}'.format(j), 'C_MED_CHANGE{}'.format(j)]]

    result.columns = ['subject_id', 'drug', 'change']

    result = result.loc[result['drug'].notnull()]

    result['drug'] = result['drug'].astype('int')

    return result


def reformat_drug_changes(df: pd.DataFrame) -> pd.DataFrame:
    """
    Reformats drug changes.

    Args:
        df: Unformatted drug changes.

    Returns:
        Reformatted drug changes.
    """

    # Determine how many entries we have.

    all_j = df.columns.str.extract(r'(\d+)').dropna().unique().astype(int)

    # Extract entries for all drugs.

    reformatted = pd.concat(melt_drug_changes(df, j) for j in all_j)

    # Remove medications newly administered (code: 15)

    reformatted = reformatted.query('change != 15')

    return reformatted


def melt_joint_injections(df: pd.DataFrame, j: int) -> pd.DataFrame:
    """
    Obtains information for the jth joint injection.

    Args:
        df: Unformatted joint injection data.
        j: Joint injection number.

    Returns:
        Information for the jth joint injection.
    """

    result = df[[
        'PatientID', 'VISITDATE', 'JT_INJ_DATE_{}'.format(j),
        'JT_INJ_MED_{}'.format(j), 'JT_INJ_SITE{}'.format(j)
    ]]

    result.columns = ['subject_id', 'visit_date', 'date', 'name', 'side']

    return result.dropna(subset=['side'])


def reformat_joint_injections(df: pd.DataFrame) -> pd.DataFrame:
    """
    Reformats joint injections.

    Args:
        df: Unformatted joint injections.

    Returns:
        Reformatted joint injections.
    """

    # Determine the number of entries.

    all_j = df.columns.str.extract(r'(\d+)').dropna().unique().astype(int)

    # Extract entries for all joint injections.

    reformatted = pd.concat(melt_joint_injections(df, j) for j in all_j)

    reformatted['date'] = convert_start_dates(reformatted['date'])

    # Filter to entries where the date of joint injection is missing or is
    # before the visit date.

    reformatted = reformatted.loc[reformatted['date'].isnull() | (reformatted[
        'date'] < reformatted['visit_date'])]

    return reformatted.drop(['visit_date', 'date', 'side'], axis=1)


@command()
@option(
    '--data-input',
    required=True,
    help='the CSV file to load medication data from')
@option(
    '--code-input',
    required=True,
    help='the CSV file to load medication codes from')
@option(
    '--output',
    required=True,
    help='the Feather file to output extracted data to')
def main(data_input, code_input, output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input, encoding='ISO-8859-1')

    info('Result: {}'.format(data.shape))

    info('Loading medication codes')

    codes = pd.read_csv(code_input, index_col='id', encoding='ISO-8859-1')

    info('Result: {}'.format(codes.shape))

    # Filter by visit number.

    info('Filtering to baseline visit and BBOP cohort 1')

    data = data.query('VisitNumber == 1 and BBOPcohort == 1')

    # Select columns.

    info('Reformatting visit dates')

    data['VISITDATE'] = pd.to_datetime(data['VISITDATE'])

    # Process drug information.

    info('Processing drug histories')

    cols_to_select_history = ['PatientID', 'VISITDATE'] + data.columns[
        data.columns.str.contains(r'^(DRUG_|START_DATE)\d+$')].tolist()

    drug_histories = data[cols_to_select_history]

    drug_histories = reformat_drug_histories(drug_histories)

    info('Processing drug changes')

    cols_to_select_change = ['PatientID'] + data.columns[
        data.columns.str.contains(r'^(C_DRUG_|C_MED_CHANGE)\d+$')].tolist()

    drug_changes = data[cols_to_select_change]

    drug_changes = reformat_drug_changes(drug_changes)

    # Process joint injections.

    info('Processing joint injections')

    cols_to_select_joint_injections = [
        'PatientID', 'VISITDATE'
    ] + data.columns[data.columns.str.contains(r'INJ_')].tolist()

    joint_injections = data[cols_to_select_joint_injections]

    joint_injections = reformat_joint_injections(joint_injections)

    joint_injections['type'] = 'joint_injection'

    # Combine the information.

    info('Combining information')

    combined = pd.concat([
        drug_histories[['subject_id', 'drug']],
        drug_changes[['subject_id', 'drug']]
    ])

    # Map all drugs to their names and types.

    info('Mapping drugs to names and types')

    mapped = combined.merge(
        codes.drop(
            ['alternate_name', 'category'], axis=1),
        how='left',
        left_on='drug',
        right_index=True)

    mapped.drop('drug', axis=1, inplace=True)

    for j in ['name', 'type']:

        mapped[j] = mapped[j].astype('category')

    # Add joint injection information.

    info('Adding joint injection information')

    mapped = pd.concat([mapped, joint_injections])

    # Cast the output and ensure that all patients are accounted for. There is
    # a difference between having no medications and missing medication data!

    info('Casting medication data')

    mapped['value'] = 1

    casted = mapped.pivot_table(
        index='subject_id',
        columns='type',
        values='value',
        aggfunc='max',
        fill_value=0)

    casted = casted.loc[data['PatientID']].fillna(0).astype(int)

    # Write the output.

    info('Writing output')

    feather.write_dataframe(casted.reset_index(), output)


if __name__ == '__main__':
    main()