"""
Summarizes medication data in the validation cohort.
"""

from click import *
from logging import *

import pandas as pd


def summarize_medications(X: pd.DataFrame, j: str) -> pd.DataFrame:
    """
    Summarizes medications.

    Args:
        X: medications
        j: the classification column

    Returns:
        counts
    """

    Y = (
        pd.Series(
            X.groupby(["visit_id", "medication", j, "status"])["subject_id"].agg(
                "count"
            ),
            name="count",
        )
        .reset_index()
        .rename(columns={j: "cls"})
    )

    Y["cls_type"] = j

    # Calculate proportions.

    Y["proportion"] = Y.groupby(["visit_id", "medication", "cls"])["count"].apply(
        lambda x: x / x.sum()
    )

    return Y


@command()
@option(
    "--medication-input",
    required=True,
    help="the Feather file to read medications from",
)
@option("--cluster-input", required=True, help="the CSV file to read clusters from")
@option("--diagnosis-input", required=True, help="the CSV file to read diagnoses from")
@option("--visit", type=IntRange(1), multiple=True, help="the visit numbers")
@option("--output", required=True, help="the CSV file to write output to")
def main(medication_input, cluster_input, diagnosis_input, visit, output):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading medications")

    X_medications = pd.read_feather(medication_input)

    debug(f"Result: {X_medications.shape}")

    info("Loading clusters")

    X_clusters = pd.read_csv(cluster_input, index_col="subject_id")

    debug(f"Result: {X_clusters.shape}")

    info("Loading diagnoses")

    X_diagnoses = pd.read_csv(diagnosis_input, index_col="subject_id")

    debug(f"Result: {X_diagnoses.shape}")

    # Filter by visit.

    if visit is not None:

        info("Filtering medications by visit")

        X_medications = X_medications.query("visit_id in @visit")

        debug(f"Result: {X_medications.shape}")

    # Filter data.

    info("Filtering medications by subject ID")

    X_medications = X_medications.query("subject_id in @X_clusters.index")

    debug(f"Result: {X_medications.shape}")

    info("Filtering diagnoses")

    X_diagnoses = X_diagnoses.loc[X_clusters.index]

    debug(f"Result: {X_diagnoses.shape}")

    # Melt data.

    info("Melting data")

    melted = X_medications.melt(
        id_vars=["subject_id", "visit_id"], var_name="medication", value_name="status"
    )

    melted["status"] = melted["status"].astype(bool)

    debug(f"Result: {melted.shape}")

    # Add clusters and diagnoses.

    info("Adding clusters and diagnoses")

    merged = melted.merge(X_clusters, left_on="subject_id", right_index=True).merge(
        X_diagnoses, left_on="subject_id", right_index=True
    )

    debug(f"Result: {merged.shape}")

    # Summarize medications.

    info("Summarizing medications")

    summary_clusters = summarize_medications(merged, "classification")

    summary_diagnoses = summarize_medications(merged, "diagnosis")

    summaries = pd.concat([summary_clusters, summary_diagnoses])

    debug(f"Result: {summaries.shape}")

    # Write output.

    info("Writing output")

    summaries.to_csv(output, index=False)


if __name__ == "__main__":
    main()
