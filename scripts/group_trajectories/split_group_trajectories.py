"""
Splits group trajectories based on baseline subcohort classification.
"""

import os.path
import pandas as pd

from click import *
from logging import *
from typing import *


def get_split_data(df: pd.DataFrame, subject_ids: pd.Index) -> pd.DataFrame:
    """
    Obtains trajectory data for the given subject IDs.

    Args:
        df: The original trajectory data.
        subject_ids: The subject IDs to extract.

    Returns:
        Extracted trajectory data.
    """

    return df.set_index('subject_id').loc[subject_ids].reset_index()


def write_output(dfs: Dict[str, pd.DataFrame], subcohort: str, path: str):
    """
    Writes the given data frame to the given path.

    Args:
        df: A mapping from subcohort to data frame.
        subcohort: The subcohort to export data for.
        path: The path to output the file to.

    Raises:
        ValueError: When the requested data frame is None or is empty and a
            path is given.
    """

    if path is None:

        return

    df = dfs.get(subcohort)

    if (df is None or df.shape[0] < 1) and path is not None:

        raise ValueError('no data for subcohort {!r}'.format(subcohort))

    info('Writing {}'.format(path))

    df.to_csv(path, index=False)


@command()
@option(
    '--data-input',
    required=True,
    metavar='DATA-INPUT',
    help='read input group trajectories from CSV file DATA-INPUT')
@option(
    '--subcohort-input',
    required=True,
    metavar='SUBCOHORT-INPUT',
    help='read input group trajectories from CSV file SUBCOHORT-INPUT')
@option(
    '--zero-output',
    metavar='ZERO-OUTPUT',
    help='output trajectories for [0] patients to ZERO-OUTPUT')
@option(
    '--localized-oligo-output',
    metavar='LOCALIZED-OLIGO-OUTPUT',
    help='output trajectories for oligo-n patients to LOCALIZED-OLIGO-OUTPUT')
@option(
    '--diffuse-oligo-output',
    metavar='DIFFUSE-OLIGO-OUTPUT',
    help='output trajectories for oligo-n patients to DIFFUSE-OLIGO-OUTPUT')
@option(
    '--non-oligo-output',
    metavar='NON-OLIGO-OUTPUT',
    help='output trajectories for non-oligo-n patients to NON-OLIGO-OUTPUT')
def main(data_input, subcohort_input, zero_output, localized_oligo_output,
         diffuse_oligo_output, non_oligo_output):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                os.path.join(
                    os.path.dirname(localized_oligo_output), 'split.log'),
                mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = pd.read_csv(data_input)

    data.info()

    info('Loading subcohorts')

    subcohorts = pd.read_csv(subcohort_input).query('visit_id == 1').drop(
        'visit_id', axis=1).set_index('subject_id').squeeze()

    info('Loaded {} entries'.format(subcohorts.size))

    # Generate the splits.

    info('Generating splits')

    subject_ids = {
        k: subcohorts.index[subcohorts == k]
        for k in ['zero', 'localized_oligo', 'diffuse_oligo', 'non_oligo']
    }

    # Extract the data.

    info('Extracting data')

    subcohort_data = {
        k: get_split_data(data, v)
        for k, v in subject_ids.items()
    }

    # Write the data.

    info('Writing output')

    write_output(subcohort_data, 'zero', zero_output)

    write_output(subcohort_data, 'localized_oligo', localized_oligo_output)

    write_output(subcohort_data, 'diffuse_oligo', diffuse_oligo_output)

    write_output(subcohort_data, 'non_oligo', non_oligo_output)


if __name__ == '__main__':
    main()