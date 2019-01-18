"""
Generates unified classifications.
"""

import numpy as np
import pandas as pd

from click import *
from logging import *


@command()
@option(
    "--input",
    required=True,
    help="the CSV file to read classifications and localizations from",
)
@option(
    "--output", required=True, help="the CSV file to write unified classifications to"
)
def main(input, output):

    basicConfig(level=DEBUG)

    # Load the assignments.

    info("Loading assignments")

    assignments = pd.read_csv(input)

    debug(f"Result: {assignments.shape}")

    # Generate unified assignments.

    info("Generating unified assignments")

    assignments["classification"] = (
        assignments["classification"] + "_" + assignments["localization"]
    )

    assignments["classification"] = np.where(
        pd.notnull(assignments["rf"]),
        assignments["classification"] + "_" + assignments["rf"],
        assignments["classification"],
    )

    assignments = assignments.drop(["localization", "rf", "threshold"], axis=1)

    debug(f"Result: {assignments.shape}")

    # Write the output.

    info("Writing output")

    assignments.to_csv(output, index=False)


if __name__ == "__main__":
    main()
