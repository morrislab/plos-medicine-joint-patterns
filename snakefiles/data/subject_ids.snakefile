"""
Obtains subject IDs.
"""

# Link inputs.

rule data_subject_ids_inputs_filters_discovery:
    output: 'inputs/data/subject_ids/filters/discovery.csv'
    input: 'outputs/data/discovery/filter.csv'
    shell: LN



rule data_subject_ids_inputs_data_validation:
    output: 'inputs/data/subject_ids/data/validation.csv'
    input: 'outputs/data/validation/joints/visit_01.csv'
    shell: LN



rule data_subject_ids_inputs:
    input:
        rules.data_subject_ids_inputs_filters_discovery.output,
        


# Discovery cohort.

rule data_subject_ids_discovery:
    output: 'tables/data/subject_ids/discovery.txt'
    log: 'tables/data/subject_ids/discovery.log'
    benchmark: 'tables/data/subject_ids/discovery.benchmark.txt'
    input: rules.data_subject_ids_inputs_filters_discovery.output
    version: v('scripts/data/subject_ids/get_discovery.py')
    shell:
        'python scripts/data/subject_ids/get_discovery.py --input {input} --output {output}' + LOG



rule data_subject_ids_validation:
    output: 'tables/data/subject_ids/validation.txt'
    log: 'tables/data/subject_ids/validation.log'
    benchmark: 'tables/data/subject_ids/validation.benchmark.txt'
    input: rules.data_subject_ids_inputs_data_validation.output
    version: v('scripts/data/subject_ids/get_validation.py')
    shell:
        'python scripts/data/subject_ids/get_validation.py --input {input} --output {output}' + LOG



# Link outputs.

rule data_subject_ids_outputs_pattern:
    output: 'outputs/data/subject_ids/{cohort}.txt'
    input: 'tables/data/subject_ids/{cohort}.txt'
    shell: LN



rule data_subject_ids_outputs:
    input:
        expand(rules.data_subject_ids_outputs_pattern.output, cohort=COHORTS),



# Targets.

rule data_subject_ids_tables:
    input:
        expand('tables/data/subject_ids/{cohort}.txt', cohort=COHORTS),



rule data_subject_ids_parameters:
    input:



rule data_subject_ids_figures:
    input:



rule data_subject_ids:
    input:
        rules.data_subject_ids_inputs.input,
        rules.data_subject_ids_tables.input,
        rules.data_subject_ids_parameters.input,
        rules.data_subject_ids_figures.input,
        rules.data_subject_ids_outputs.input,
