"""
Patient counts for cluster trajectories
"""

COHORTS = ['discovery', 'validation']



# Generate counts.

def cluster_trajectories_patient_counts_data_pattern_input(wildcards):
    return {
        'discovery': 'tables/cluster_trajectories/discovery/clusters/localized_partial.csv',
        'validation':
        'tables/cluster_trajectories/validation/clusters/localized.csv'
    }[wildcards.cohort] 

rule cluster_trajectories_patient_counts_data_pattern:
    output: 'tables/cluster_trajectories/patient_counts/{cohort}.csv'
    log: 'tables/cluster_trajectories/patient_counts/{cohort}.log'
    benchmark: 'tables/cluster_trajectories/patient_counts/{cohort}.txt'
    input: cluster_trajectories_patient_counts_data_pattern_input
    version: v('scripts/cluster_trajectories/patient_counts/count_patients.py')
    shell:
        'python scripts/cluster_trajectories/patient_counts/count_patients.py --input {input} --output {output}' + LOG



rule cluster_trajectories_patient_counts_data:
    input:
        expand(rules.cluster_trajectories_patient_counts_data_pattern.output, cohort=COHORTS),



# Plot counts.

rule cluster_trajectories_patient_counts_fig_pattern:
    output: 'figures/cluster_trajectories/patient_counts/{cohort}.pdf'
    log: 'figures/cluster_trajectories/patient_counts/{cohort}.log'
    benchmark: 'figures/cluster_trajectories/patient_counts/{cohort}.txt'
    input: rules.cluster_trajectories_patient_counts_data_pattern.output
    params:
        width=6,
        height=3,
    version: v('scripts/cluster_trajectories/patient_counts/plot_counts.R')
    shell:
        'Rscript scripts/cluster_trajectories/patient_counts/plot_counts.R --input {input} --output {output} --width {params.width} --height {params.height}' + LOG



rule cluster_trajectories_patient_counts_fig:
    input:
        expand(rules.cluster_trajectories_patient_counts_fig_pattern.output, cohort=COHORTS),



# Targets.

rule cluster_trajectories_patient_counts_tables:
    input:
        rules.cluster_trajectories_patient_counts_data.input,



rule cluster_trajectories_patient_counts_parameters:
    input:



rule cluster_trajectories_patient_counts_figures:
    input:
        rules.cluster_trajectories_patient_counts_fig.input,



rule cluster_trajectories_patient_counts:
    input:
        rules.cluster_trajectories_patient_counts_tables.input,
        rules.cluster_trajectories_patient_counts_parameters.input,
        rules.cluster_trajectories_patient_counts_figures.input,