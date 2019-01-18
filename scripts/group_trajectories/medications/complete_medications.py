"""
For each visit, ensures that all possible combinations of subject ID and
medication are covered.
"""

import pandas as pd

from click import *
from logging import *


def complete(df: pd.DataFrame) -> pd.DataFrame:
    """
    Completes a given data frame by subject ID and medication.

    Args:
        df: the data to complete.
    """

    baseline_classifications = df[['subject_id', 'baseline_classification'
                                   ]].drop_duplicates().set_index('subject_id')

    df = df.drop(['visit_id', 'baseline_classification'], axis=1)

    index_keys = ['subject_id', 'medication']

    df = df.set_index(index_keys)

    mux = pd.MultiIndex.from_product(
        [df.index.levels[k] for k in range(len(index_keys))], names=index_keys)

    try:

        df = df.reindex(mux, fill_value=False).reset_index()

    except:

        import IPython
        IPython.embed()
        raise

    return df.set_index('subject_id').join(
        baseline_classifications).reset_index()


@command()
@option(
    '--input',
    required=True,
    help='the Feather file containing medication information')
@option(
    '--output',
    required=True,
    help='the Feather file to write completed data to')
def main(input: str, output: str):

    basicConfig(level=DEBUG)

    info('Loading data')

    data = pd.read_feather(input)

    debug(f'Result: {data.shape}')

    info('Completing data')

    completed_data = data.groupby('visit_id').apply(complete)

    import IPython
    IPython.embed()
    raise Exception()


if __name__ == '__main__':
    main()