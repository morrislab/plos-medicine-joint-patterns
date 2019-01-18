"""
Concatenates Feather files together.
"""

from click import *
from logging import *

import pandas as pd
import tqdm


@command()
@option(
    "--input", required=True, multiple=True, help="the Feather files to concatenate"
)
@option(
    "--output", required=True, help="the Feather file to write the concatenated data to"
)
def main(input, output):

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading and concatenating data")

    X = pd.concat(pd.read_feather(x) for x in tqdm.tqdm(input))

    debug(f"Result: {X.shape}")

    # Write the output.

    info("Writing output")

    X.reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
