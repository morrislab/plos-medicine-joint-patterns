"""
Calculates patient group trajectories.
"""

include: 'cluster_trajectories/discovery.snakefile'
include: 'cluster_trajectories/validation.snakefile'
# include: 'cluster_trajectories/patient_counts.snakefile'



# Targets.

rule cluster_trajectories_tables:
    input:
        rules.cluster_trajectories_discovery_tables.input,
        rules.cluster_trajectories_validation_tables.input,
        # rules.cluster_trajectories_patient_counts_tables.input,



rule cluster_trajectories_parameters:
    input:
        rules.cluster_trajectories_discovery_parameters.input,
        rules.cluster_trajectories_validation_parameters.input,



rule cluster_trajectories_figures:
    input:
        rules.cluster_trajectories_discovery_figures.input,
        rules.cluster_trajectories_validation_figures.input,
        # rules.cluster_trajectories_patient_counts_figures.input,



rule cluster_trajectories:
    input:
        rules.cluster_trajectories_tables.input,
        rules.cluster_trajectories_parameters.input,
        rules.cluster_trajectories_figures.input,
