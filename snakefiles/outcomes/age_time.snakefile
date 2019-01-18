"""
Associations of patient groups with age of diagnosis and time to diagnosis.
"""

DATA_INPUT = 'inputs/outcomes/age_time/data/{cohort}.feather'
CLUSTER_INPUT = 'inputs/outcomes/age_time/clusters/{cohort}.csv'
DIAGNOSIS_INPUT = 'inputs/outcomes/age_time/diagnoses/{cohort}.csv'

# Link inputs.

rule outcomes_age_time_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/{cohort}/basics.feather'
    shell: LN



rule outcomes_age_time_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/{cohort}.csv'
    shell: LN



rule outcomes_age_time_inputs_diagnoses_pattern:
    output: DIAGNOSIS_INPUT
    input: 'outputs/diagnoses/{cohort}.csv'
    shell: LN



rule outcomes_age_time_inputs:
    input:
        expand(rules.outcomes_age_time_inputs_data_pattern.output, cohort='discovery'),
        expand(rules.outcomes_age_time_inputs_clusters_pattern.output, cohort='discovery'),
        expand(rules.outcomes_age_time_inputs_diagnoses_pattern.output, cohort='discovery'),



# Plot ages of diagnosis and times to diagnosis.

rule outcomes_age_time_fig_pattern:
    output: 'figures/outcomes/age_time/{cohort}.pdf'
    log: 'figures/outcomes/age_time/{cohort}.log'
    benchmark: 'figures/outcomes/age_time/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
        diagnoses=DIAGNOSIS_INPUT,
    params:
        width=4.75,
        height=4.75,
    version: v('scripts/outcomes/plot_age_time.R')
    shell:
        'Rscript scripts/outcomes/plot_age_time.R --data-input {input.data} --classification-input {input.clusters} --diagnosis-input {input.diagnoses} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule outcomes_age_time_fig:
    input:
        expand(rules.outcomes_age_time_fig_pattern.output, cohort='discovery'),



# Conduct statistics.

rule outcomes_age_time_stats_pattern:
    output: 'tables/outcomes/age_time/stats/{cohort}.csv'
    log: 'tables/outcomes/age_time/stats/{cohort}.log'
    benchmark: 'tables/outcomes/age_time/stats/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
        diagnoses=DIAGNOSIS_INPUT,
    version: v('scripts/outcomes/do_age_time_stats.R')
    shell:
        'Rscript scripts/outcomes/do_age_time_stats.R --data-input {input.data} --classification-input {input.clusters} --diagnosis-input {input.diagnoses} --output {output}' + LOG



rule outcomes_age_time_stats:
    input:
        expand(rules.outcomes_age_time_stats_pattern.output, cohort='discovery'),


# Targets.

rule outcomes_age_time_tables:
    input:
        rules.outcomes_age_time_stats.input,



rule outcomes_age_time_parameters:
    input:



rule outcomes_age_time_figures:
    input:
        rules.outcomes_age_time_fig.input,



rule outcomes_age_time:
    input:
        rules.outcomes_age_time_inputs.input,
        rules.outcomes_age_time_tables.input,
        rules.outcomes_age_time_parameters.input,
        rules.outcomes_age_time_figures.input
