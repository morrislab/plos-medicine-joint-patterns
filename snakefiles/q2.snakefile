"""
Calculates reconstruction accuracy of the original data using Q2.
"""

# SOURCES = {
#     'discovery': ['l2_l1_l0', 'l1_l0'],
#     'validation': ['l2_l1_l0', 'l1_l0'],
#     'validation_projections': ['l2_l1_l0', 'l1_l0']
# }

DATA = 'inputs/q2/data/{cohort}.csv'
RECONSTRUCTION = 'inputs/q2/reconstructions/{cohort}/{source}.csv'

SOURCES = ['clusters', 'diagnoses', 'l2_l1_l0', 'l1_l0']
COHORTS = ['discovery', 'validation', 'validation_projections']



# Link inputs.

rule q2_inputs_data_validation_projections:
    output: 'inputs/q2/data/validation_projections.csv'
    input: 'inputs/q2/data/validation.csv'
    shell: LN



rule q2_inputs_data_pattern:
    output: DATA
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule q2_inputs_data:
    input:
        expand(DATA, cohort=COHORTS),



rule q2_inputs_reconstructions_diagnoses_validation_projections:
    output: expand(RECONSTRUCTION, cohort='validation_projections', source='diagnoses')
    input: expand(RECONSTRUCTION, cohort='validation', source='diagnoses')
    shell: LN



rule q2_inputs_reconstructions_diagnoses_pattern:
    output: expand(RECONSTRUCTION, cohort='{cohort}', source='diagnoses')
    input: 'outputs/reconstructions/diagnoses/{cohort}.csv'
    shell: LN



rule q2_inputs_reconstructions_pattern:
    output: RECONSTRUCTION
    input: 'outputs/reconstructions/{cohort}/{source}.csv'
    shell: LN



rule q2_inputs_reconstructions:
    input:
        expand(RECONSTRUCTION, cohort=COHORTS, source=SOURCES),



rule q2_inputs:
    input:
        rules.q2_inputs_data.input,
        rules.q2_inputs_reconstructions.input,



# Reconstruction accuracy on the original data.

rule q2_q2_pattern:
    output: 'tables/q2/{cohort}/{source}.txt'
    log: 'tables/q2/{cohort}/{source}.log'
    benchmark: 'tables/q2/{cohort}/{source}.benchmark.txt'
    input:
        data=DATA,
        reconstructions=RECONSTRUCTION,
    version: v('scripts/q2/calculate_q2.py')
    shell:
        'python scripts/q2/calculate_q2.py --data-input {input.data} --reconstruction-input {input.reconstructions} --output {output}' + LOG



rule q2_q2:
    input:
        expand(rules.q2_q2_pattern.output, cohort=COHORTS, source=SOURCES),



# Targets.

rule q2_tables:
    input:
        rules.q2_q2.input,



rule q2_parameters:
    input:



rule q2_figures:
    input:



rule q2:
    input:
        rules.q2_inputs.input,
        rules.q2_tables.input,
        rules.q2_parameters.input,
        rules.q2_figures.input,
