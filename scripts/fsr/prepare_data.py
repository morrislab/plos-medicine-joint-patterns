"""
Prepares data forward stepwise regression.
"""

import feather
import pandas as pd

from click import *
from logging import *
from scipy.stats import boxcox, kurtosis, skew, normaltest


def transform_categories(df: pd.DataFrame) -> pd.DataFrame:
    """
    Transforms categorical data in the given data frame to dummy variables.

    The level with the lowest number of ones will be dropped.

    Args:
        df: The data in which to transform categorical data.

    Returns:
        Data with categories transformed to dummy variables.
    """

    to_append = []

    for j in df.columns:

        if df[j].dtype == object or hasattr(df[j], 'cat'):

            info('Transforming {!r} to dummy variables'.format(j))

            dummies = pd.get_dummies(df[j])

            dummies.rename(
                columns={x: '{}__{}'.format(j, x)
                         for x in dummies.columns},
                inplace=True)

            # Drop the level with the fewest zeroes.

            dummies_sum = dummies.sum()

            dummies.drop(dummies_sum.argmin(), axis=1, inplace=True)

            # Comvert column names to lowercase names.

            new_names = dummies.columns.str.lower().str.replace(r'[^a-z0-9_]+',
                                                                '_')

            dummies.columns = new_names

            df.drop(j, axis=1, inplace=True)

            to_append.append(dummies)

    return pd.concat([df] + to_append, axis=1)


@command()
@option(
    '--input', required=True, help='the Feather file to read input data from')
@option(
    '--output', required=True, help='the Feather file to write output data to')
@option(
    '--response-variable', default='dai', help='the response variable to use')
def main(input, output, response_variable):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    # Load the data.

    info('Loading data')

    data = feather.read_dataframe(input)

    info('Result: {}'.format(data.shape))

    # Remove missing values.

    info('Removing missing values')

    data.dropna(inplace=True)

    # Transform the response variable. Conduct a Box-Cox transformation if the
    # variable has excessive kurtosis or skewness.

    info('Transforming response variables')

    response_data = data[response_variable]

    info('Skewness: {}'.format(skew(response_data)))

    info('Kurtosis: {}'.format(kurtosis(response_data)))

    normal_test_statistic, normal_test_p = normaltest(response_data)

    info("D'Agostino and Pearson statistic: {}, P = {}".format(
        normal_test_statistic, normal_test_p))

    if normal_test_p < 0.05:

        response_transformed, lamb = boxcox(response_data - response_data.min()
                                            + 1)

        info('Transformed response with lambda = {}'.format(lamb))

        data[response_variable] = response_transformed

        info('Transformed skewness: {}'.format(skew(response_transformed)))

        info('Transformed kurtosis: {}'.format(kurtosis(response_transformed)))

    # Transform categorical variables to categories.

    info('Transforming categorical variables to dummy variables')

    data = transform_categories(data)

    # Write the output.

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':
    main()