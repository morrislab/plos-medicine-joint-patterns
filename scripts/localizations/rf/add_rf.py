"""
Adds rheumatoid factor status to the localizations.
"""

from click import *
from logging import *

import pandas as pd


def process_rf(x: str) -> str:
    """
    Processes an RF status to a label.
    """

    if pd.isnull(x) or x == "ND":

        return "rf_na"

    if x == "POS":

        return "rf_pos"

    if x == "NEG":

        return "rf_neg"

    raise ValueError(f"cannot parse RF status: {x!r}")


@command()
@option("--cluster-input", required=True, help="the CSV file to load assignments from")
@option(
    "--demographics-input",
    required=True,
    help="the Feather file to load demographics from",
)
@option("--output", required=True, help="the CSV file to write output to")
@option("--restrict", multiple=True, help="the clusters to restrict RF assignments to")
def main(cluster_input, demographics_input, output, restrict):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading clusters")

    clusters = pd.read_csv(cluster_input, index_col="subject_id")

    debug(f"Result: {clusters.shape}")

    info("Loading RF statuses")

    rf_statuses = (
        pd.read_feather(demographics_input)
        .set_index("subject_id")[["labs_rf_1_res"]]
        .rename(columns={"labs_rf_1_res": "rf"})
    )

    rf_statuses["rf"] = rf_statuses["rf"].apply(process_rf)

    rf_statuses = rf_statuses.query("rf in ['rf_pos', 'rf_neg']")

    debug(f"Result: {rf_statuses.shape}")

    # Join RF statuses.

    info("Joining RF statuses")

    if restrict:

        # We assume that patients with missing RF statuses are RF-negative.

        rf_clusters = (
            clusters.query("classification in @restrict")
            .join(rf_statuses, how="left")
            .fillna({"rf": "rf_neg"})
        )

        non_rf_clusters = clusters.query("classification not in @restrict")

        clusters = pd.concat([rf_clusters, non_rf_clusters], sort=True)

    else:

        # We assume that patients with missing RF statuses are RF-negative.

        clusters = clusters.join(rf_statuses, how="left").fillna({"rf": "rf_neg"})

    debug(f"Result: {clusters.shape}")

    # Write output.

    info("Writing output")

    clusters.to_csv(output)


if __name__ == "__main__":
    main()
