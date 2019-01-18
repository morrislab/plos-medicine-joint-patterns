"""
Obtains data for the time-to-zero analysis using the Cox proportional hazards
model.
"""

import pandas as pd

from click import *
from logging import *

# Define study length as months.

VISITS = {2: 6, 3: 12, 4: 18, 5: 24, 6: 36, 7: 48, 8: 60}


def convert_visit_to_months(x: float) -> int:
    """
    Converts a visit number to months.

    Args:
        x: The visit number to convert.

    Returns:
        The number of months.
    """

    if x <= 5:

        return (x - 1) * 6

    return (x - 3) * 12


def calculate_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculates the first time to having zero sites and an event status.

    Args:
        df: The data frame to perform calculations on.

    Returns:
        The visit that a patient first experiences zero sites and an event
        status. If a patient never experiences zero site involvement, the
        highest recorded visit is returned with an event status of `0`,
        indicating right-censoring.
    """

    zero_visit = df.loc[df['count'] == 0, 'visit_id'].min()

    is_zero_visit_notnull = pd.notnull(zero_visit)

    return pd.DataFrame({
        'visit':
        [zero_visit if is_zero_visit_notnull else df['visit_id'].max()],
        'event_status': [int(is_zero_visit_notnull)]
    })


@command()
@option(
    '--site-input',
    required=True,
    help='the Feather file to read site involvement data from')
@option(
    '--localization-input',
    required=True,
    help='the CSV file to read clusters and localizations from')
@option(
    '--diagnosis-input',
    required=True,
    help='the CSV file to read diagnoses from')
@option('--output', required=True, help='the Feather file to write output to')
@option('--max-visit', type=int, help='the maximum visit number to consider')
def main(site_input: str, localization_input: str, diagnosis_input: str,
         output: str, max_visit: int):

    basicConfig(level=DEBUG)

    # Load the data.

    info('Loading site information')

    sites = pd.read_feather(site_input)

    debug(f'Result: {sites.shape}')

    info('Loading localizations')

    localizations = pd.read_csv(localization_input, index_col='subject_id')

    debug(f'Result: {localizations.shape}')

    info('Loading diagnoses')

    diagnoses = pd.read_csv(diagnosis_input, index_col='subject_id')

    debug(f'Result: {diagnoses.shape}')

    # Filter the site involvement data.

    info('Filtering involvements')

    sites = sites.loc[(sites['visit_id'] > 0)
                      & (sites['visit_id'] <= max_visit)]

    sites = sites.loc[sites['subject_id'].isin(localizations.index)]

    debug(f'Result: {sites.shape}')

    # For each patient, determine the time to no joint involvement if
    # possible.

    info('Calculating joint counts and censoring statuses')

    sites.set_index(['subject_id', 'visit_id'], inplace=True)

    joint_counts = sites.sum(axis=1)

    joint_counts.name = 'count'

    joint_counts = joint_counts.reset_index()

    statuses = joint_counts.groupby('subject_id').apply(
        calculate_data).reset_index('subject_id').reset_index(
            drop=True).set_index('subject_id')

    # Convert visit numbers to durations.

    info('Converting visit numbers to durations')

    durations = {t: convert_visit_to_months(t) for t in range(max_visit + 1)}

    statuses['duration'] = statuses['visit'].apply(durations.__getitem__)

    statuses.drop('visit', axis=1, inplace=True)

    # Combine the data.

    info('Combining data')

    combined = localizations[['classification', 'localization'
                              ]].join(statuses).join(diagnoses[['diagnosis']])

    # Write the data.

    info('Writing data')

    for j in ['classification', 'localization', 'diagnosis']:

        combined[j] = combined[j].astype('category')

    combined.reset_index().to_feather(output)


if __name__ == '__main__':
    main()