"""
Obtains score trajectories for patients.
"""

import argparse
import logging
import numpy as np
import pandas as pd
import string
import tqdm

from sklearn.externals import joblib


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--visit-data', type=argparse.FileType('rU'), metavar='VISIT-DATA',
        required=True, nargs='+',
        help='read joint information from CSV files %(metavar)ss')

    parser.add_argument(
        '--baseline-scores', type=argparse.FileType('rU'),
        metavar='BASELINE-SCORES', required=True,
        help='load baseline scores from CSV file %(metavar)s')

    parser.add_argument(
        '--scaling-parameters', type=argparse.FileType('rU'),
        metavar='SCALING-PARAMETERS', required=True, nargs='+',
        help='read scaling parameters from %(metavar)ss')

    parser.add_argument(
        '--nmf-models', type=argparse.FileType('r'), metavar='NMF-MODEL',
        required=True, nargs='+',
        help='read NMF models from %(metavar)ss')

    parser.add_argument(
        '--output', required=True, metavar='OUTPUT',
        help='write output to a Feather file %(metavar)s')

    parser.add_argument(
        '--log', metavar='LOG',
        help='write logging information to %(metavar)s')

    result = parser.parse_args()

    if len(result.scaling_parameters) != len(result.nmf_models):

        parser.error(
            'number of --scaling-parameters must match number of --nmf-models')

    return result


def configure_logging(log=None):
    """
    Configures logging.

    :param str log: the path to log messages to
    """

    if log:

        logging.basicConfig(level=logging.DEBUG, filename=log,
                            filemode='w',
                            format='%(asctime)s %(levelname)-8s %(message)s')

        console = logging.StreamHandler()

        console.setLevel(logging.INFO)

        console.setFormatter(logging.Formatter('%(message)s'))

        logging.getLogger().addHandler(console)

    else:

        logging.basicConfig(level=logging.INFO, format='%(message)s')


def _load_visit_data(handle):
    """
    Loads visit data from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading visit data from {}'.format(handle.name))

    result = pd.read_csv(handle, index_col=0)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def _load_scaling_parameters(handle):
    """
    Loads scaling parameters from the given handle.

    :param io.file handle

    :rtype pd.DataFrame
    """

    logging.info('Loading scaling parameters from {}'.format(handle.name))

    result = pd.read_csv(handle, index_col=0)

    logging.info('Result is a table with shape {}'.format(result.shape))

    return result


def _load_nmf_model(handle):
    """
    Loads an NMF model from the given handle.

    :param io.file handle

    :rtype sklearn.decomposition.NMF
    """

    logging.info('Loading NMF model from {}'.format(handle.name))

    result = joblib.load(handle.name)

    return result


def load_data(visit_data_handles, baseline_score_handle,
              scaling_parameter_handles, nmf_model_handles):
    """
    Loads visit data, baseline clusters, scaling parameters, and NMF models
    from the given handles.

    :param List[io.file] visit_data_handles

    :param io.file baseline_score_handle

    :param List[io.file] scaling_parameter_handles

    :param List[io.file] nmf_model_handles

    :rtype Tuple[List[pd.DataFrame], pd.DataFrame, List[pd.DataFrame],
        List[sklearn.decomposition.NMF]]
    """

    visit_data = [_load_visit_data(h) for h in visit_data_handles]

    logging.info('Loading baseline scores')

    baseline_scores = pd.read_csv(baseline_score_handle, index_col=0)

    logging.info('Result is a table with shape {}'.format(
        baseline_scores.shape))

    scaling_parameters = [_load_scaling_parameters(
        h) for h in scaling_parameter_handles]

    nmf_models = [_load_nmf_model(x) for x in nmf_model_handles]

    return visit_data, baseline_scores, scaling_parameters, nmf_models


def filter_data(dfs, patient_ids):
    """
    Filters the given data frames to the given patient IDs.

    :param List[pd.DataFrame] dfs

    :param pd.Series[int] patient_ids

    :rtype List[pd.DataFrame]
    """

    logging.info('Filtering visit data')

    results = [df.loc[df.index.intersection(patient_ids)] for df in dfs]

    logging.info('Results are tables with shapes {}'.format(
        [x.shape for x in results]))

    return results


def reformat_baseline_clusters(series):
    """
    Reformats the given baseline clusters to letters.

    :param pd.Series[int] series

    :rtype pd.Series[str]
    """

    logging.info('Reformatting baseline clusters')

    result = pd.Series(list(string.ascii_uppercase))[series - 1]

    result.index = series.index

    return result


def _get_visit_scores(visit_number, df, scaling_parameters, nmf_models):
    """
    Calculates factors with the given data for a single visit, scaling
    parameters, and models.

    :param int visit_number

    :param pd.DataFrame df

    :param List[pd.DataFrame] scaling_parameters

    :param List[sklearn.decomposition.NMF] nmf_models

    :rtype pd.DataFrame
    """

    result = df

    for sp, nm in zip(scaling_parameters, nmf_models):

        result = (result + sp['shift']) * sp['scale']

        result = pd.DataFrame(nm.transform(
            result), index=result.index, columns=pd.np.arange(nm.n_components,
                                                              dtype=int) + 1)

    result = pd.melt(result.reset_index(), id_vars=['SubjectID'],
                     var_name='factor', value_name='score')

    result.insert(1, 'visit_number', visit_number)

    return result


def _remove_gaps_patient(df):
    """
    Removes gaps in cluster assignments for a given patient.

    :param pd.DataFrame

    :rtype pd.DataFrame
    """

    unique_visits = df['visit_number'].unique()

    diff = unique_visits[1:] - unique_visits[:-1]

    if (diff > 1).any():

        ix = np.where(diff > 1)[0][0]

        visit = unique_visits[ix]

        return df[df['visit_number'] <= visit]

    return df


def _remove_gaps(df):
    """
    Removes given scores for patients after the time point where no score
    exists.

    :param pd.DataFrame df

    :rtype pd.DataFrame
    """

    logging.info('Removing gaps in scores')

    g = df.groupby('SubjectID')

    return g.apply(_remove_gaps_patient).reset_index(drop=True)


def get_scores(data, baseline_scores, scaling_parameters, nmf_models):
    """
    Obtains cluster assignments with the given data, baseline clusters, scaling
    parameters, and models.

    :param List[pd.DataFrame] data

    :param pd.DataFrame baseline_scores

    :param List[pd.DataFrame] scaling_parameters

    :param List[sklearn.decomposition.NMF] nmf_models

    :rtype pd.DataFrame
    """

    logging.info('Obtaining cluster assignments')

    baseline_scores = pd.melt(baseline_scores.reset_index(), id_vars=[
                              'SubjectID'], var_name='factor',
                              value_name='score')

    baseline_scores.insert(1, 'visit_number', 1)

    future_scores = [_get_visit_scores(i + 2, d, scaling_parameters,
                                       nmf_models) for i, d in tqdm.tqdm(
        enumerate(data), total=len(data))]

    combined_scores = pd.concat([baseline_scores] + future_scores)

    # Apply a filter to the scores: patients who are missing data at any one
    # time point should not have scores after that time point.

    return _remove_gaps(combined_scores)


def write_output(df, filename):
    """
    Writes the given data frame to the given file.

    :param pd.DataFrame df

    :param str filename
    """

    logging.info('Writing output')

    df.to_csv(filename, index=False)


if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Conduct the analysis.

    visit_data, baseline_scores, scaling_parameters, nmf_models = load_data(
        args.visit_data, args.baseline_scores, args.scaling_parameters,
        args.nmf_models)

    filtered_data = filter_data(visit_data, baseline_scores.index)

    scores = get_scores(filtered_data, baseline_scores,
                        scaling_parameters, nmf_models)

    write_output(scores, args.output)

    logging.info('Done')
