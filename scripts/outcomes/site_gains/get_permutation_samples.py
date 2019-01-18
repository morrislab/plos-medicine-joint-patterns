"""
Obtains samples for the permutation test determining which sites are
overrepresented in terms of the number of patients who gain it at later visits.
"""

import feather
import joblib as jl
import numpy as np
import pandas as pd
import tqdm

from click import *
from logging import *
from typing import *


def filter_representative_sites_patient(
        df: pd.DataFrame, representative_sites: List[str]) -> pd.DataFrame:
    """
    Filters out representative sites from the given data frame for a single
    patient.

    Args:
        df: The data frame to filter.
        representative_sites: Representative sites to filter out.

    Returns:
        The filtered data.
    """

    return df.loc[~(df['site'].isin(representative_sites))]


def filter_representative_sites(
        df: pd.DataFrame, clusters: pd.Series,
        representative_sites: pd.DataFrame) -> pd.DataFrame:
    """
    Filters out representative sites from the given data frame.

    Args:
        df: The data frame to filter.
        clusters: Cluster assignments.
        representative_sites: Representative sites for each cluster.

    Returns:
        The filtered data.
    """

    return pd.concat(
        filter_representative_sites_patient(
            df.loc[df['subject_id'] == i],
            representative_sites.loc[[clusters.loc[i]]]['site'].tolist())
        for i in tqdm.tqdm(clusters.index))


def get_differences(df_future: pd.DataFrame,
                    df_baseline: pd.DataFrame) -> pd.DataFrame:
    """
    Calculates differences between future involvements and baseline
    involvements.

    Args:
        df_future: Involvements in the future.
        df_baseline: Involvements at baseline.

    Returns:
        The differences.
    """

    return (df_future.set_index(['subject_id', 'site', 'classification']) -
            df_baseline.set_index(['subject_id', 'site', 'classification'])
            ).reset_index().dropna(subset=['value'])


def shuffle_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Shuffles the given data.

    Args:
        df: The data to shuffle.

    Returns:
        The shuffled data.
    """

    df_shuffled = df[['subject_id', 'value']].copy()

    df_shuffled['value'] = np.random.permutation(df_shuffled['value'])

    return df_shuffled


def get_stats(x: pd.Series) -> pd.DataFrame:
    """
    Calculates the gain probability from the given series, as well as the
    number of patients considered and the number of patients who gained the
    site specified by the series.

    Args:
        x: An indicator specifying whether a patient has gained involvement in
            a site at any future time point.

    Returns:
        The gain probability, the number of patients considered, and the number
        of patients gaining involvement in the site specified by the input.
    """

    mask = x > 0

    return pd.DataFrame({'n': [x.size], 'n_gained': [mask.sum()]})


def do_permutation_test(df_future: pd.DataFrame,
                        df_baseline: pd.DataFrame,
                        seed: int) -> pd.DataFrame:
    """
    Conducts a permutation test.

    Args:
        df_future: Future involvement data (merged).
        df_baseline: Baseline data.
        seed: The seed to use for shuffling the data.

    Returns:
        For each patient group and site, the number of patients who gain that
        site.
    """

    # Shuffle the data.

    np.random.seed(seed)

    df_future_shuffled = df_future.groupby(
        ['classification', 'site']).apply(shuffle_data).reset_index(
            ['classification', 'site']).reset_index(drop=True)

    # Calculate differences between baseline and future.

    differences = get_differences(df_future_shuffled, df_baseline)

    # Calculate stats.

    stats = differences.groupby(
        ['classification', 'site'])['value'].apply(get_stats).reset_index(
            ['classification', 'site']).reset_index(drop=True)

    stats['seed'] = seed

    return stats


def do_permutation_tests(df_future: pd.DataFrame,
                         df_baseline: pd.DataFrame,
                         seeds: List[int],
                         cores: int) -> pd.DataFrame:
    """
    Conducts permutation tests.

    The input data frames should contain the classifications as a
    `classification` column.

    Args:
        df_future: Future involvement data (merged).
        df_baseline: Baseline data.
        clusters: Patient group assignments.
        seeds: The seeds to use for shuffling the data.
        cores: The number of cores to run the analysis with.

    Returns:
        For each patient group and site and iteration, the number of patients
        who gain that site.
    """

    it = tqdm.tqdm(seeds)

    results = (do_permutation_test(df_future, df_baseline, seed)
               for seed in it) if cores == 1 else jl.Parallel(n_jobs=cores)(
                   jl.delayed(do_permutation_test)(df_future, df_baseline,
                                                   seed) for seed in it)

    concatenated = pd.concat(results)

    for j in ['seed', 'site', 'classification']:

        concatenated[j] = concatenated[j].astype('category')

    return concatenated


@command()
@option(
    '--cluster-input',
    required=True,
    help='the CSV file containing cluster assignments')
@option(
    '--representative-site-input',
    required=True,
    help='the CSV file containing representative sites')
@option(
    '--site-input',
    required=True,
    help='the Feather file containing site involvements')
@option(
    '--seedlist',
    type=File('rU'),
    required=True,
    help='the text file to load seeds from')
@option(
    '--visit',
    required=True,
    multiple=True,
    help='the future visit numbers to consider (multiple allowed)')
@option(
    '--output',
    required=True,
    help='the Feather file to output gain information to')
@option(
    '--cores',
    type=int,
    default=1,
    help='the number of cores to run the analysis with')
def main(cluster_input, representative_site_input, site_input, seedlist, visit,
         output, cores):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading clusters')

    clusters = pd.read_csv(cluster_input, index_col=0, squeeze=True)

    info('Result: {}'.format(clusters.shape))

    info('Loading representative sites')

    representative_sites = pd.read_csv(
        representative_site_input, index_col='factor')

    info('Result: {}'.format(representative_sites.shape))

    info('Loading involvements')

    involvements = feather.read_dataframe(site_input)

    info('Result: {}'.format(involvements.shape))

    info('Loading seeds')

    seeds = [int(x.strip()) for x in seedlist]

    info('Result: {} seeds'.format(len(seeds)))

    # Filter the data to the relevant visits and patients.

    info('Filtering data to relevant visits and patients')

    subject_id_mask = involvements['subject_id'].isin(clusters.index)

    involvements_baseline = involvements.loc[subject_id_mask & (involvements[
        'visit_id'] == 1)].drop(
            'visit_id', axis=1)

    involvements_future = involvements.loc[subject_id_mask & involvements[
        'visit_id'].isin(visit)]

    # Melt all involvements.

    info('Melting involvements')

    involvements_baseline_melted = involvements_baseline.melt(
        id_vars='subject_id', var_name='site')

    involvements_future_melted = involvements_future.melt(
        id_vars=['subject_id', 'visit_id'], var_name='site')

    # For each patient, filter all involvements to non-representative sites.

    info('Filtering involvements to non-representative sites')

    involvements_baseline_nonrep = filter_representative_sites(
        involvements_baseline_melted, clusters, representative_sites)

    involvements_future_nonrep = filter_representative_sites(
        involvements_future_melted, clusters, representative_sites)

    # Merge cluster assignments in.

    info('Merging cluster assignments')

    involvements_baseline_nonrep = involvements_baseline_nonrep.merge(
        clusters.to_frame(),
        how='inner',
        left_on='subject_id',
        right_index=True)

    involvements_future_nonrep = involvements_future_nonrep.merge(
        clusters.to_frame(),
        how='inner',
        left_on='subject_id',
        right_index=True)

    # Among future involvements, calculate whether sites were involved at any
    # time in the future.

    info('Calculating future data')

    involvements_future_nonrep = involvements_future_nonrep.groupby(
        ['classification', 'subject_id', 'site'])['value'].max().reset_index()

    # Conduct the permutation tests.

    info('Conducting permutation tests')

    test_results = do_permutation_tests(
        involvements_future_nonrep, involvements_baseline_nonrep, seeds, cores)

    # Write the output.

    info('Writing output')

    feather.write_dataframe(test_results, output)


if __name__ == '__main__':

    main()
