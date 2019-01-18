"""
Obtains score trajectories for all patients in REACCH OUT.
"""

import click
import feather
import functools as ft
import pandas as pd
import tqdm

from logging import *
from sklearn.externals import joblib


def _load_scaling_parameters(handle):
    """
    Loads scaling parameters from the given handle.

    :param io.file handle

    :rtype: pd.DataFrame
    """

    info('Loading scaling parameters from {}'.format(handle.name))

    result = pd.read_csv(handle, index_col=0)

    info('Result is a table with shape {}'.format(result.shape))

    return result


def _load_nmf_model(handle):
    """
    Loads an NMF model from the given handle.

    :param io.file handle

    :rtype: sklearn.decomposition.NMF
    """

    info('Loading NMF model from {}'.format(handle.name))

    result = joblib.load(handle.name)

    # XXX

    result.beta_loss = 'frobenius'

    return result


def load_data(joint_path, scaling_parameter_handles, nmf_model_handles):
    """
    Loads joint involvement data, scaling parameters, and NMF models
    from the given handles.

    :param str joint_path

    :param List[io.file] scaling_parameter_handles

    :param List[io.file] nmf_model_handles

    :rtype: Tuple[List[pd.DataFrame], List[pd.DataFrame],
        List[sklearn.decomposition.NMF]]
    """

    info('Loading joint involvement data')

    joint_data = feather.read_dataframe(joint_path)

    info('Loaded a table with shape {}'.format(joint_data.shape))

    scaling_parameters = [
        _load_scaling_parameters(h) for h in scaling_parameter_handles
    ]

    nmf_models = [_load_nmf_model(x) for x in nmf_model_handles]

    return joint_data, scaling_parameters, nmf_models


def _filter_trajectories(df, max_visit):
    """
    Filters trajectories for a patient in the given table to ensure a
    contiguous trajectory.

    :param pd.DataFrame df

    :param int max_visit

    :rtype: pd.DataFrame
    """

    df = df.loc[df['visit_id'] > 0.]

    if max_visit is not None:

        df = df.loc[df['visit_id'] <= max_visit]

    sorted_visits = df['visit_id'].sort_values()

    # Must start at the baseline visit (1).

    if sorted_visits.min() > 1:

        return df.loc[[]]

    # Return a contiguous range of visits.

    gaps = sorted_visits.diff()

    mask = pd.isnull(gaps) | (gaps == 1)

    if mask.min() == False:

        return df.loc[:mask.argmin()].head(-1)

    return df


def filter_trajectories(df, max_visit):
    """
    Filters visits in the given table to ensure contiguous trajectories.

    In other words, patients cannot have breaks between visits.

    Trajectories must also start at baseline (visit 1).

    :param pd.DataFrame df

    :param int max_visit

    :rtype: pd.DataFrame
    """

    info('Filtering entries by trajectories')

    tqdm.tqdm.pandas()

    result = df.groupby('subject_id').progress_apply(
        ft.partial(
            _filter_trajectories, max_visit=max_visit)).reset_index(drop=True)

    info('Result is a table with shape {}'.format(result.shape))

    return result


def get_scores(data, scaling_parameters, nmf_models):
    """
    Obtains cluster assignments with the given data, baseline clusters, scaling
    parameters, and models.

    :param List[pd.DataFrame] data

    :param List[pd.DataFrame] scaling_parameters

    :param List[sklearn.decomposition.NMF] nmf_models

    :rtype: pd.DataFrame
    """

    info('Calculating scores')

    result = data.set_index(['subject_id', 'visit_id'])

    for sp, nm in zip(scaling_parameters, nmf_models):

        result = (result + sp['shift']) * sp['scale']

        result = pd.DataFrame(
            nm.transform(result),
            index=result.index,
            columns=pd.np.arange(
                nm.n_components, dtype=int) + 1)

    melted_result = pd.melt(
        result.reset_index(),
        id_vars=['subject_id', 'visit_id'],
        var_name='factor',
        value_name='score')

    info('Result is a table with shape {}'.format(melted_result.shape))

    return melted_result


def write_output(df, filename):
    """
    Writes the given data frame to the given file.

    :param pd.DataFrame df

    :param str filename
    """

    info('Writing output')

    df['subject_id'] = df['subject_id'].astype('category')

    df.to_csv(filename, index=False)


@click.command()
@click.option(
    '--joint-data-input',
    required=True,
    help='read joint information from CSV file JOINT_DATA_INPUT')
@click.option(
    '--scaling-parameter-input',
    type=click.File('rU'),
    required=True,
    multiple=True,
    help='read scaling parameters from SCALING_PARAMETER_INPUT')
@click.option(
    '--nmf-model-input',
    type=click.File('rU'),
    required=True,
    multiple=True,
    help='read NMF models from NMF_MODEL_INPUT')
@click.option(
    '--output', required=True, help='write output to CSV file OUTPUT')
@click.option(
    '--max-visit',
    type=int,
    metavar='MAX-VISIT',
    help='calculate scores for visits up to MAX-VISIT')
def main(joint_data_input, scaling_parameter_input, nmf_model_input, output,
         max_visit):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    joint_data, scaling_parameters, nmf_models = load_data(
        joint_data_input, list(scaling_parameter_input), list(nmf_model_input))

    filtered_data = filter_trajectories(joint_data, max_visit)

    scores = get_scores(filtered_data, scaling_parameters, nmf_models)

    write_output(scores, output)


if __name__ == '__main__':
    main()
