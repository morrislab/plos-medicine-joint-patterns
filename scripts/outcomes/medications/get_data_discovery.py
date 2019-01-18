"""
Collects data for the discovery cohort.
"""

from click import *
from logging import *

import janitor
import pandas as pd
import re


@command()
@option(
    "--localization-input",
    required=True,
    help="the CSV file to load localizations from",
)
@option(
    "--medication-input",
    required=True,
    help="the Feather file to load medications from",
)
@option(
    "--joint-injection-input",
    required=True,
    help="the Feather file to load joint injections from",
)
@option("--output", required=True, help="the Feather file to output data to")
@option(
    "--visit-id",
    type=IntRange(1),
    required=True,
    multiple=True,
    help="the visit IDs to consider",
)
def main(localization_input, medication_input, joint_injection_input, output, visit_id):

    basicConfig(level=DEBUG)

    # Load data.

    info("Loading localizations")
    X_localizations = pd.read_csv(localization_input, index_col="subject_id")
    debug(f"Result: {X_localizations.shape}")

    info("Loading medications")
    X_medications = pd.read_feather(medication_input)
    debug(f"Result: {X_medications.shape}")

    info("Loading joint injections")
    X_joint_injections = pd.read_feather(joint_injection_input)
    debug(f"Result: {X_joint_injections.shape}")

    # Filter the data.

    info("Filtering medications")
    X_medications = X_medications.query("visit_id in @visit_id")
    debug(f"Result: {X_medications.shape}")

    info("Filtering joint injections")
    X_joint_injections = X_joint_injections.query("visit_id in @visit_id")
    debug(f"Result: {X_joint_injections.shape}")

    # Determine medication statuses. Drop NSAIDs and IVIG.

    info("Determining medication statuses")
    medication_statuses = X_medications.set_index(["subject_id", "visit_id"]).apply(
        lambda x: x.isin(["CUR", "DC"])
    )
    medication_statuses = medication_statuses.rename(
        columns={j: re.sub(r"_status$", "", j) for j in medication_statuses.columns}
    )
    medication_statuses = (
        medication_statuses.drop(["nsaid", "ivig"], axis=1)
        .rename(columns={j: f"{j}s" for j in medication_statuses.columns})
        .reset_index()
        .melt(
            id_vars=["subject_id", "visit_id"],
            var_name="medication",
            value_name="status",
        )
    )
    debug(f"Result: {medication_statuses.shape}")

    # Determine joint injection statuses.

    info("Determining joint injection statuses")
    joint_injection_statuses = pd.Series(
        X_joint_injections.set_index(["subject_id", "visit_id"]).eval(
            "injection_status != 'NONE' and days_max > 0"
        ),
        name="status",
    ).reset_index()
    joint_injection_statuses["medication"] = "joint_injections"
    debug(f"Result: {joint_injection_statuses.shape}")

    # Concatenate tables together.

    info("Concatenating statuses")
    concatenated = pd.concat([medication_statuses, joint_injection_statuses], sort=True)
    debug(f"Result: {concatenated.shape}")

    # Add localizations.

    info("Adding localizations")
    joined = concatenated.merge(
        X_localizations.drop("threshold", axis=1),
        how="inner",
        left_on="subject_id",
        right_index=True,
    )
    debug(f"Result: {joined.shape}")

    # Write output.

    info("Writing output")
    joined.encode_categorical(
        ["medication", "classification", "localization"]
    ).reset_index(drop=True).to_feather(output)


if __name__ == "__main__":
    main()
