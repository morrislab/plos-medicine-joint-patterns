"""
Associations with treatment decisions.
"""

LOCALIZATION_INPUT = 'inputs/outcomes/medications/localizations/{cohort}.csv'
DIAGNOSIS_INPUT = 'inputs/outcomes/medications/diagnoses/{cohort}.csv'
MEDICATION_INPUT = 'inputs/outcomes/medications/medications/{cohort}.feather'
JOINT_INJECTION_INPUT = 'inputs/outcomes/medications/joint_injections/{cohort}.feather'

VISITS = config.outcomes.medications.visits



# Link inputs.

rule outcomes_medications_inputs_clusters_pattern:
    output: LOCALIZATION_INPUT
    input: 'outputs/localizations/assignments/{cohort}.csv'
    shell: LN



rule outcomes_medications_inputs_medications_pattern:
    output: MEDICATION_INPUT
    input: 'outputs/data/{cohort}/medications.feather'
    shell: LN



rule outcomes_medications_inputs_joint_injections_pattern:
    output: JOINT_INJECTION_INPUT
    input: 'outputs/data/{cohort}/joint_injections.feather'
    shell: LN



rule outcomes_medications_inputs:
    input:
        expand(rules.outcomes_medications_inputs_clusters_pattern.output, cohort='discovery'),
        expand(rules.outcomes_medications_inputs_medications_pattern.output, cohort='discovery'),
        expand(rules.outcomes_medications_inputs_joint_injections_pattern.output, cohort='discovery'),



# Generate data.

rule outcomes_medications_data_pattern:
    output: 'tables/outcomes/medications/data/{cohort}.feather'
    log: 'tables/outcomes/medications/data/{cohort}.log'
    benchmark: 'tables/outcomes/medications/data/{cohort}.txt'
    input:
        localizations=LOCALIZATION_INPUT,
        medications=MEDICATION_INPUT,
        joint_injections=JOINT_INJECTION_INPUT,
    params:
        visit_ids=VISITS,
    version: v('scripts/outcomes/medications/get_data_discovery.py')
    run:
        visit_ids = ' '.join(f'--visit-id {x}' for x in params.visit_ids)
        shell('python scripts/outcomes/medications/get_data_discovery.py --localization-input {input.localizations} --medication-input {input.medications} --joint-injection-input {input.joint_injections} --output {output} {visit_ids}' + LOG)



rule outcomes_medications_data:
    input:
        expand(rules.outcomes_medications_data_pattern.output, cohort='discovery'),



# Generate statistics.

rule outcomes_medications_stats_pattern:
    output: 'tables/outcomes/medications/stats/{cohort}.xlsx'
    log: 'tables/outcomes/medications/stats/{cohort}.log'
    benchmark: 'tables/outcomes/medications/stats/{cohort}.txt'
    input: 'tables/outcomes/medications/data/{cohort}.feather'
    version: v('scripts/outcomes/medications/do_stats.R')
    shell:
        'Rscript scripts/outcomes/medications/do_stats.R --input {input} --output {output}' + LOG



rule outcomes_medications_stats:
    input:
        expand(rules.outcomes_medications_stats_pattern.output, cohort='discovery'),



# Generate a plot.

rule outcomes_medications_fig_pattern:
    output: 'figures/outcomes/medications/{cohort}.pdf'
    log: 'figures/outcomes/medications/{cohort}.log'
    benchmark: 'figures/outcomes/medications/{cohort}.txt'
    input: rules.outcomes_medications_data_pattern.output
    params:
        width=5,
        height=10,
    version: v('scripts/outcomes/medications/plot_medications.R')
    shell:
        'Rscript scripts/outcomes/medications/plot_medications.R --input {input} --output {output} --width {params.width} --height {params.height}' + LOG



rule outcomes_medications_fig:
    input:
        expand(rules.outcomes_medications_fig_pattern.output, cohort='discovery'),



# Targets.

rule outcomes_medications_tables:
    input:
        rules.outcomes_medications_data.input,
        rules.outcomes_medications_stats.input,



rule outcomes_medications_parameters:
    input:



rule outcomes_medications_figures:
    input:
        rules.outcomes_medications_fig.input,



rule outcomes_medications:
    input:
        rules.outcomes_medications_inputs.input,
        rules.outcomes_medications_tables.input,
        rules.outcomes_medications_parameters.input,
        rules.outcomes_medications_figures.input,
