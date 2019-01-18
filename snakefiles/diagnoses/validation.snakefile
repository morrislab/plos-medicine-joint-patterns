"""
Extracts diagnoses for the validation cohort.
"""

DATA_INPUT = 'inputs/diagnoses/validation/joints.csv'
DEMOGRAPHICS_INPUT = 'inputs/diagnoses/validation/basics.feather'
MAPPING_INPUT = 'data/diagnoses/mapping.yaml'


# Link inputs.

rule diagnoses_validation_inputs_data:
    output: DATA_INPUT
    input: 'outputs/data/validation/joints/visit_01.csv'
    shell: LN



rule diagnoses_validation_inputs_basics:
    output: DEMOGRAPHICS_INPUT
    input: 'outputs/data/validation/basics.feather'
    shell: LN



rule diagnoses_validation_inputs:
    input:
        rules.diagnoses_validation_inputs_data.output,
        rules.diagnoses_validation_inputs_basics.output,



# Diagnoses for the validation cohort.

rule diagnoses_validation_diagnoses_raw:
    output: 'tables/diagnoses/validation/raw.csv'
    log: 'tables/diagnoses/validation/raw.log'
    benchmark: 'tables/diagnoses/validation/raw.txt'
    input:
        data=DATA_INPUT,
        demographics=DEMOGRAPHICS_INPUT,
    version: v('scripts/diagnoses/validation/extract.py')
    shell:
        'python scripts/diagnoses/validation/extract.py --data-input {input.data} --demographics-input {input.demographics} --output {output}' + LOG



# Map the diagnoses.

rule diagnoses_validation_diagnoses_mapped:
    output: 'tables/diagnoses/validation/mapped.csv'
    log: 'tables/diagnoses/validation/mapped.log'
    benchmark: 'tables/diagnoses/validation/mapped.txt'
    input:
        diagnoses=rules.diagnoses_validation_diagnoses_raw.output,
        mapping=MAPPING_INPUT,
    version: v('scripts/diagnoses/validation/map.py')
    shell:
        'python scripts/diagnoses/validation/map.py --diagnosis-input {input.diagnoses} --mapping-input {input.mapping} --output {output}' + LOG



# Link outputs.

rule diagnoses_validation_outputs_diagnoses:
    output: 'outputs/diagnoses/validation.csv'
    input: rules.diagnoses_validation_diagnoses_mapped.output
    shell: LN



rule diagnoses_validation_outputs:
    input:
        rules.diagnoses_validation_outputs_diagnoses.output,



# Targets.

rule diagnoses_validation_tables:
    input:
        rules.diagnoses_validation_diagnoses_raw.output,
        rules.diagnoses_validation_diagnoses_mapped.output,



rule diagnoses_validation_parameters:
    input:



rule diagnoses_validation_figures:
    input:



rule diagnoses_validation:
    input:
        rules.diagnoses_validation_tables.input,
        rules.diagnoses_validation_parameters.input,
        rules.diagnoses_validation_figures.input,
