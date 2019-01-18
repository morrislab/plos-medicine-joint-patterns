"""
Obtains data for the time-to-zero analysis using the Cox proportional hazards
model.
"""

from click import *
from logging import *

import pandas as pd
import janitor

# Define study length as months.

VISITS = {2: 6, 3: 12, 4: 18, 5: 24, 6: 36, 7: 48, 8: 60}


def convert_visit_to_months(x: float) -> int:
    """
    Converts a visit number to months.

    Args:
        x: The visit number to convert.
    """

    if x <= 5:

        return (x - 1) * 6

    return (x - 3) * 12


def calculate_data(X: pd.DataFrame) -> pd.DataFrame:
    """
    Calculates the first time to having zero sites and an event status.

    Args:
        X: joint counts

    Returns:
        The visit that a patient first experiences zero sites and an event
        status. If a patient never experiences zero site involvement, the
        highest recorded visit is returned with an event status of `0`,
        indicating right-censoring.
    """

    zero_visit = X.loc[X["count"] == 0, "visit_id"].min()

    is_zero_visit_notnull = pd.notnull(zero_visit)

    return pd.DataFrame(
        {
            "visit": [zero_visit if is_zero_visit_notnull else X["visit_id"].max()],
            "event_status": [int(is_zero_visit_notnull)],
        }
    )


@command()
@option(
    "--site-input",
    required=True,
    help="the Feather file to read site involvement data from",
)
@option(
    "--localization-input",
    required=True,
    help="the CSV file to read clusters and localizations from",
)
@option("--diagnosis-input", required=True, help="the CSV file to read diagnoses from")
@option("--output", required=True, help="the Feather file to write output to")
@option("--max-visit", type=IntRange(1), help="the maximum visit number to consider")
def main(site_input, localization_input, diagnosis_input, output, max_visit):

    basicConfig(level=DEBUG)

    # Load the data.

    info("Loading site information")

    sites = pd.read_feather(site_input)

    debug(f"Result: {sites.shape}")

    info("Loading localizations")

    localizations = pd.read_csv(localization_input, index_col="subject_id")

    debug(f"Result: {localizations.shape}")

    info("Loading diagnoses")

    diagnoses = pd.read_csv(diagnosis_input, index_col="subject_id")

    debug(f"Result: {diagnoses.shape}")

    # Filter the site involvement data.

    info("Filtering involvements")

    sites = sites.query("0 < visit_id <= @max_visit").query(
        "subject_id in @localizations.index"
    )

    # sites = sites.loc[sites["subject_id"].isin(localizations.index)]

    debug(f"Result: {sites.shape}")

    # For each patient, determine the time to no joint involvement if
    # possible.

    info("Calculating joint counts and censoring statuses")

    joint_counts = pd.Series(
        sites.set_index(["subject_id", "visit_id"]).sum(axis=1), name="count"
    ).reset_index()

    statuses = (
        joint_counts.groupby("subject_id")
        .apply(calculate_data)
        .reset_index("subject_id")
        .reset_index(drop=True)
        .set_index("subject_id")
    )

    # Convert visit numbers to durations.

    info("Converting visit numbers to durations")

    durations = {t: convert_visit_to_months(t) for t in range(max_visit + 1)}

    statuses["duration"] = statuses["visit"].apply(durations.__getitem__)

    statuses = statuses.drop("visit", axis=1)

    # Combine the data.

    info("Combining data")

    combined = (
        localizations[["classification", "localization", "rf"]]
        .join(statuses)
        .join(diagnoses[["diagnosis"]])
    )

    # Write the data.

    info("Writing data")

    combined = combined.encode_categorical(
        ["classification", "localization", "diagnosis", "rf"]
    )

    combined.reset_index().to_feather(output)


if __name__ == "__main__":
    main()
