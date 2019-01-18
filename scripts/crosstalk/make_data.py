"""
Generates data for analyzing distributions of scores among patient groups.

Normalizes scores by patient. The end result is that for each patient, scores
will be in the range [0, 1] with the highest-scoring factor having a normalized
score of 1.
"""

from click import *
from logging import *

import janitor as jn
import pandas as pd
import string


def get_threshold(ctx, param, value):
    """
    Obtains a threshold from the given parameter.
    """

    if value is not None:

        try:

            return int(value)

        except ValueError:

            if value not in ['cohort', 'cluster']:

                raise ValueError('must be a number, "cohort", or "cluster"')

            return value

    return 0


def normalize(X: pd.DataFrame) -> pd.DataFrame:
    """
    Normalizes scores to the range [0, 1] for a single patient.

    Args:
        X: data frame containing patient factor scores for a single patient
    
    Returns:
        normalized patient factor scores
    """

    Y = X.set_index(['factor'])[['score']]

    Y['score'] /= Y['score'].max()

    return Y


def z_transform(x: pd.Series) -> pd.Series:
    """
    Z-transforms scores.

    Args:
        x: values to Z-transform

    Returns:
        Z-transformed scores
    """

    return (x - x.mean()) / x.std()


@command()
@option(
    '--score-input', required=True, help='the CSV file to read scores from')
@option(
    '--localization-input',
    required=True,
    help='the CSV file to read localization data from')
@option('--output', required=True, help='the Feather file to write output to')
@option(
    '--letters/--no-letters',
    default=False,
    help='whether to use letters for factor names')
@option('--count-input', help='the CSV file to read joint counts from')
@option(
    '--threshold',
    callback=get_threshold,
    help=(
        'the joint count to calculate to set as a minimum inclusion threshold; '
        '"cohort": calculate a global median threshold from the cohort; '
        '"cluster": calculate a per-cluster median threshold'))
def main(score_input, localization_input, output, letters, count_input,
         threshold):

    basicConfig(level=DEBUG)

    if threshold == 'none' and not count_input:

        raise Exception(
            '--count-input must be defined if --threshold is not "none"')

    # Load data.

    info('Loading scores')

    scores = pd.read_csv(score_input)

    debug(f'Result: {scores.shape}')

    info('Loading localizations')

    localizations = pd.read_csv(
        localization_input, index_col='subject_id').drop(
            'threshold', axis=1)

    debug(f'Result: {localizations.shape}')

    # Filter the data if needed.

    if threshold != 0:

        info('Loading joint counts')

        counts = pd.read_csv(count_input, index_col=0)

        debug(f'Result: {counts.shape}')

        if isinstance(threshold, int):

            info('Filtering scores')

            filtered_counts = counts.query('count >= @threshold')

            scores = scores.set_index('subject_id').loc[
                filtered_counts.index].reset_index()

            debug(f'Result: {scores.shape}')

        elif threshold == 'cohort':

            info('Calculating median count')

            median_count = counts['count'].median()

            debug(f'Median: {median_count} joints')

            info('Filtering scores')

            filtered_counts = counts.query('count >= @median_count')

            scores = scores.set_index('subject_id').loc[
                filtered_counts.index].reset_index()

            debug(f'Result: {scores.shape}')

        else:

            info('Joining joint counts with classifications')

            joined_counts = counts.join(localizations[['classification']])

            debug(f'Result: {joined_counts.shape}')

            before_n_patients = joined_counts['classification'].value_counts()

            for k, v in before_n_patients.iteritems():

                debug(f'- {k}: {v} patients')

            info('Calculating median counts')

            median_counts = pd.Series(
                joined_counts.groupby('classification')['count'].median(),
                name='median')

            debug(f'Result: {median_counts.shape}')

            for k, v in median_counts.iteritems():

                debug(f'- {k}: {v} joints')

            info('Filtering scores')

            joined_medians = joined_counts.reset_index(
            ).set_index('classification').join(
                median_counts.to_frame()).reset_index().set_index('subject_id')

            to_retain = joined_medians['count'] >= joined_medians['median']

            scores = scores.set_index('subject_id').loc[
                to_retain].reset_index()

            after_n_patients = scores.set_index('subject_id').join(
                localizations['classification']).reset_index()[
                    'classification'].value_counts()

            for k, v in after_n_patients.iteritems():

                debug(f'- {k}: {v} patients')

            debug(f'Result: {scores.shape}')

    # Melt data.

    info('Melting scores')

    scores = scores.melt(
        id_vars='subject_id', var_name='factor', value_name='score')

    scores['factor'] = scores['factor'].astype(int)

    debug(f'Result: {scores.shape}')

    # Patient-normalize patient factor scores.

    info('Patient-normalizing scores')

    scores = scores.groupby('subject_id').apply(normalize).reset_index()

    debug(f'Result: {scores.shape}')

    # Calculate Z-scores.

    info('Calculating Z-scores')

    scores['z_score'] = scores.groupby('factor')['score'].apply(z_transform)

    debug(f'Result: {scores.shape}')

    # Rename factors.

    info('Renaming factors')

    scores['factor'] = [
        f'<{string.ascii_uppercase[x - 1]}>' for x in scores['factor']
    ] if letters else [f'<{x:02d}>' for x in scores['factor']]

    # Join data.

    info('Joining data')

    joined = scores.set_index('subject_id').join(localizations)

    debug(f'Result: {joined.shape}')

    # Write output.

    info('Writing output')

    joined = joined.pipe(
        jn.encode_categorical, columns=['classification', 'localization'])

    joined.reset_index().to_feather(output)


if __name__ == '__main__':
    main()