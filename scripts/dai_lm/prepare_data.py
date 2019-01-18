"""
Prepares data for linear regression.
"""

import feather

from click import *
from logging import *
from scipy.stats import boxcox, kurtosis, skew, normaltest


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

    # Write the output.

    info('Writing output')

    feather.write_dataframe(data, output)


if __name__ == '__main__':
    main()