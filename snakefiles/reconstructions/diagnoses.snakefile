"""
Reconstructions of the original data for diagnoses.
"""

DATA = 'inputs/reconstructions/joints/{cohort}.csv'
DIAGNOSES = 'inputs/reconstructions/diagnoses/{cohort}.csv'

COHORTS = ['discovery', 'validation']



# Link inputs.

rule reconstructions_diagnoses_inputs_data_pattern:
    output: DATA
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule reconstructions_diagnoses_inputs_diagnoses_pattern:
    output: DIAGNOSES
    input: 'outputs/diagnoses/roots/{cohort}.csv'
    shell: LN



rule reconstructions_diagnoses_inputs:
    input:
        expand(rules.reconstructions_diagnoses_inputs_data_pattern.output, cohort=COHORTS),
        expand(rules.reconstructions_diagnoses_inputs_diagnoses_pattern.output, cohort=COHORTS),



# Generate reconstructions.

rule reconstructions_diagnoses_results_pattern:
    output: 'tables/reconstructions/diagnoses/{cohort}.csv'
    log: 'tables/reconstructions/diagnoses/{cohort}.log'
    benchmark: 'tables/reconstructions/diagnoses/{cohort}.txt'
    input:
        data=DATA,
        diagnoses=DIAGNOSES,
    version: v('scripts/reconstructions/reconstruct_from_diagnoses.py')
    shell:
        'python scripts/reconstructions/reconstruct_from_diagnoses.py --data-input {input.data} --diagnosis-input {input.diagnoses} --output {output}' + LOG



rule reconstructions_diagnoses_results:
    input:
        expand(rules.reconstructions_diagnoses_results_pattern.output, cohort=COHORTS),



# Link outputs.

rule reconstructions_diagnoses_outputs_pattern:
    output: 'outputs/reconstructions/diagnoses/{cohort}.csv'
    input: rules.reconstructions_diagnoses_results_pattern.output
    shell: LN



rule reconstructions_diagnoses_outputs:
    input:
        expand(rules.reconstructions_diagnoses_outputs_pattern.output, cohort=COHORTS),



# Targets.

rule reconstructions_diagnoses_tables:
    input:
        rules.reconstructions_diagnoses_results.input,



rule reconstructions_diagnoses_parameters:
    input:



rule reconstructions_diagnoses_figures:
    input:



rule reconstructions_diagnoses:
    input:
        rules.reconstructions_diagnoses_inputs.input,
        rules.reconstructions_diagnoses_tables.input,
        rules.reconstructions_diagnoses_parameters.input,
        rules.reconstructions_diagnoses_figures.input,
