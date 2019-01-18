"""
Obtains medications for patients at subsequent time points.
"""

import pandas as pd

from click import *
from logging import *


@command()
@option(
    '--medication-input',
    required=True,
    help='the Feather file to read medications from')
@option(
    '--joint-injection-input',
    required=True,
    help='the Feather file to read joint injections from')
@option(
    '--output',
    required=True,
    help='the CSV file to write filtered medications to')
def main(medication_input: str, joint_injection_input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading medications')

    medications = pd.read_feather(medication_input).set_index(
        ['subject_id', 'visit_id'])

    debug(f'Result: {medications.shape}')

    info('Loading joint injections')

    joint_injections = pd.read_feather(joint_injection_input).set_index(
        ['subject_id', 'visit_id'])

    debug(f'Result: {joint_injections.shape}')

    # Melt the medications.

    info('Melting medications')

    medications = pd.melt(
        medications.reset_index(),
        id_vars=['subject_id', 'visit_id'],
        var_name='medication',
        value_name='status')

    medications['medication'] = medications['medication'].str.replace(
        '_status$', '')

    medications['status'] = ~(medications['status'].isin(['NONE', 'NEW']))

    # Calculate joint injection statuses.

    info('Calculating joint injection statuses')

    joint_injections['status'] = (joint_injections['injection_status'] !=
                                  'NONE') & (
                                      (joint_injections['days_max'] > 0)
                                      | joint_injections['days_max'].isnull())

    # Concatenate medications and joint injections.

    info('Concatenating medications and joint injections')

    joint_injections['medication'] = 'joint_injection'

    joint_injections.reset_index(inplace=True)

    df_concat = pd.concat(x[['subject_id', 'visit_id', 'medication', 'status']]
                          for x in [medications, joint_injections])

    df_concat = df_concat.loc[df_concat['subject_id'].notnull()
                              & df_concat['visit_id'].notnull()]

    debug(f'Result: {df_concat.shape}')

    # Write the output.

    info('Writing output')

    df_concat['visit_id'] = df_concat['visit_id'].astype(int)

    df_concat['medication'] = df_concat['medication'].astype('category')

    df_concat.reset_index(drop=True).to_feather(output)


if __name__ == '__main__':
    main()