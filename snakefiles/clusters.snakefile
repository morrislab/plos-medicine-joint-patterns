"""
Patient groups.
"""

LEVELS = config.clusters.levels
FINAL_LEVEL = LEVELS[-1]

INPUT = 'inputs/clusters/scores/{cohort}/{level}.csv'


# Link inputs.

rule clusters_inputs_pattern:
    output: INPUT
    input: 'outputs/nmf/{cohort}/{level}/model/scores.csv'
    shell: LN



rule clusters_inputs:
    input:
        expand(rules.clusters_inputs_pattern.output, cohort=COHORTS, level=LEVELS),



# Cluster assignments.

rule clusters_clusters_pattern:
    output: 'tables/clusters/{cohort}/{level}.csv'
    log: 'tables/clusters/{cohort}/{level}.log'
    benchmark: 'tables/clusters/{cohort}/{level}.txt'
    input: INPUT
    version: v('scripts/nmf/get_clusters.py')
    shell:
        'python scripts/nmf/get_clusters.py --input {input} --output {output} --letters' + LOG



rule clusters_clusters:
    input:
        expand(rules.clusters_clusters_pattern.output, cohort=COHORTS, level=LEVELS),



# Plot the number of patients.

rule clusters_counts_fig_pattern:
    output: 'figures/clusters/counts/{cohort}/{level}.pdf'
    log: 'figures/clusters/counts/{cohort}/{level}.log'
    benchmark: 'figures/clusters/counts/{cohort}/{level}.txt'
    input: rules.clusters_clusters_pattern.output
    params:
        width=3,
        height=3,
    version: v('scripts/general/plot_patient_counts.R')
    shell:
        'Rscript scripts/general/plot_patient_counts.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule clusters_counts_fig:
    input:
        expand(rules.clusters_counts_fig_pattern.output, cohort=COHORTS, level=LEVELS),



# Link outputs.

rule clusters_outputs_levels_pattern:
    output: 'outputs/clusters/levels/{cohort}/{level}.csv'
    input: rules.clusters_clusters_pattern.output
    shell: LN



rule clusters_outputs_levels:
    input:
        expand(rules.clusters_outputs_levels_pattern.output, cohort=COHORTS, level=LEVELS),



rule clusters_outputs_final_pattern:
    output: 'outputs/clusters/{cohort}.csv'
    input: expand(rules.clusters_outputs_levels_pattern.output, cohort='{cohort}', level=FINAL_LEVEL),
    shell: LN



rule clusters_outputs_final:
    input:
        expand(rules.clusters_outputs_final_pattern.output, cohort=COHORTS),



rule clusters_outputs:
    input:
        rules.clusters_outputs_levels.input,
        rules.clusters_outputs_final.input,



# Targets.

rule clusters_tables:
    input:
        rules.clusters_clusters.input,



rule clusters_parameters:
    input:



rule clusters_figures:
    input:
        rules.clusters_counts_fig.input,



rule clusters:
    input:
        rules.clusters_inputs.input,
        rules.clusters_tables.input,
        rules.clusters_parameters.input,
        rules.clusters_figures.input,
        rules.clusters_outputs.input,
