"""
Generates cluster trajectories for the discovery cohort.
"""

include: 'discovery/data.snakefile'
include: 'discovery/heatmap.snakefile'



# Targets.

rule cluster_trajectories_discovery_tables:
    input:
        rules.cluster_trajectories_discovery_data_tables.input,
        rules.cluster_trajectories_discovery_heatmap_tables.input,



rule cluster_trajectories_discovery_parameters:
    input:
        rules.cluster_trajectories_discovery_data_parameters.input,
        rules.cluster_trajectories_discovery_heatmap_parameters.input,



rule cluster_trajectories_discovery_figures:
    input:
        rules.cluster_trajectories_discovery_data_figures.input,
        rules.cluster_trajectories_discovery_heatmap_figures.input,



rule cluster_trajectories_discovery:
    input:
        rules.cluster_trajectories_discovery_tables.input,
        rules.cluster_trajectories_discovery_parameters.input,
        rules.cluster_trajectories_discovery_figures.input,
