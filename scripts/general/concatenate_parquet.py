"""
Concatenates Parquet files together.
"""

from click import *
from logging import *

import pandas as pd
import tqdm


@command()
@option(
    "--input", required=True, multiple=True, help="the Parquet files to concatenate"
)
@option(
    "--output", required=True, help="the Feather file to write the concatenated data to"
)
@option(
    "--reset-index/--no-reset-index", default=False, help="whether to reset the index"
)
@option(
    "--compression",
    type=Choice(["none", "snappy", "gzip", "brotil"]),
    default="gzip",
    show_default=True,
    help="the compression method to use",
)
def main(input, output, reset_index, compression):

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading and concatenating data")

    X = pd.concat(pd.read_parquet(x) for x in tqdm.tqdm(input))

    debug(f"Result: {X.shape}")

    # Write the output.

    info("Writing output")

    if reset_index:

        X = X.reset_index(drop=True)

    X.to_parquet(output, compression=None if compression == "none" else compression)


if __name__ == "__main__":
    main()
