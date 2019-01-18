
"""
Demographic data.
"""

DISCOVERY_FILE_MAP = {
    'chaq': 'CHAQ',
    'enthesitis': 'ENTHESITIS',
    'examinations': 'EXAMINATIONS',
    'jaqq': 'JAQQ',
    'labs': 'LABS',
    'labs_pgada': 'INTERIM_LABS_PGADA',
    'qoml': 'QoML',
}

DISCOVERY_TYPES = ['patient_basics'] + list(DISCOVERY_FILE_MAP.keys())
VALIDATION_TYPES = ['all']



# Link inputs.

rule data_demographics_inputs_discovery_patient_basics:
    output: 'inputs/data/demographics/discovery/patient_basics.xls'
    input: join(config.data.source_dirs.discovery, 'master_files', 'PATIENT_BASICS.xls')
    shell: LN



rule data_demographics_inputs_discovery_pattern:
    output: 'inputs/data/demographics/discovery/{type}.xls'
    input: lambda wildcards: join(config.data.source_dirs.discovery, 'primary_data_files', f'{DISCOVERY_FILE_MAP[wildcards.type]}.xls')
    shell: LN



ruleorder: data_demographics_inputs_discovery_patient_basics > data_demographics_inputs_discovery_pattern



rule data_demographics_inputs_discovery:
    input:
        expand(rules.data_demographics_inputs_discovery_pattern.output, type=DISCOVERY_TYPES),



rule data_demographics_inputs_validation:
    output: 'inputs/data/demographics/validation/all.xls'
    input: join(config.data.source_dirs.validation, 'Final data.xls')
    shell: LN



rule data_demographics_inputs:
    input:
        rules.data_demographics_inputs_discovery.input,
        rules.data_demographics_inputs_validation.output,



# Extract the data.

rule data_demographics_extracted_discovery_patient_basics:
    output: 'tables/data/demographics/extracted/discovery/patient_basics.feather'
    log: 'tables/data/demographics/extracted/discovery/patient_basics.log'
    benchmark: 'tables/data/demographics/extracted/discovery/patient_basics.txt'
    input: rules.data_demographics_inputs_discovery_patient_basics.output
    version: v('scripts/data/demographics/discovery/extract_basics.py')
    shell:
        'python scripts/data/demographics/discovery/extract_basics.py --input {input} --output {output}' + LOG



rule data_demographics_extracted_discovery_pattern:
    output: 'tables/data/demographics/extracted/discovery/{type}.feather'
    log: 'tables/data/demographics/extracted/discovery/{type}.log'
    benchmark: 'tables/data/demographics/extracted/discovery/{type}.txt'
    input: 'inputs/data/demographics/discovery/{type}.xls'
    version: v('scripts/data/demographics/extract_data.py')
    shell:
        'python scripts/data/demographics/extract_data.py --input {input} --output {output}' + LOG



rule data_demographics_extracted_validation_pattern:
    output: 'tables/data/demographics/extracted/validation/{type}.feather'
    log: 'tables/data/demographics/extracted/validation/{type}.log'
    benchmark: 'tables/data/demographics/extracted/validation/{type}.txt'
    input: 'inputs/data/demographics/validation/{type}.xls'
    version: v('scripts/data/demographics/extract_data.py')
    shell:
        'python scripts/data/demographics/extract_data.py --input {input} --output {output}' + LOG



ruleorder: data_demographics_extracted_discovery_patient_basics > data_demographics_extracted_discovery_pattern



rule data_demographics_extracted:
    input:
        expand(rules.data_demographics_extracted_discovery_pattern.output, type=DISCOVERY_TYPES),
        expand(rules.data_demographics_extracted_validation_pattern.output, type=VALIDATION_TYPES),



# Filter to patients of interest.

rule data_demographics_filtered_discovery_pattern:
    output: 'tables/data/demographics/filtered/discovery/{type}.feather'
    log: 'tables/data/demographics/filtered/discovery/{type}.log'
    benchmark: 'tables/data/demographics/filtered/discovery/{type}.txt'
    input:
        data=lambda wildcards: 'tables/data/demographics/extracted/discovery/patient_basics.feather' if wildcards.type == 'patient_basics' else f'tables/data/demographics/extracted/discovery/{wildcards.type}.feather',
        subject_ids='tables/data/subject_ids/discovery.txt',
    version: v('scripts/data/demographics/filter_data.py')
    shell:
        'python scripts/data/demographics/filter_data.py --data-input {input.data} --subject-id-input {input.subject_ids} --output {output}' + LOG



rule data_demographics_filtered_validation_pattern:
    output: 'tables/data/demographics/filtered/validation/{type}.feather'
    log: 'tables/data/demographics/filtered/validation/{type}.log'
    benchmark: 'tables/data/demographics/filtered/validation/{type}.txt'
    input:
        data=rules.data_demographics_extracted_validation_pattern.output,
        subject_ids='tables/data/subject_ids/validation.txt',
    version: v('scripts/data/demographics/filter_data.py')
    shell:
        'python scripts/data/demographics/filter_data.py --data-input {input.data} --subject-id-input {input.subject_ids} --output {output}' + LOG



rule data_demographics_filtered:
    input:
        expand(rules.data_demographics_filtered_discovery_pattern.output, type=DISCOVERY_TYPES),
        expand(rules.data_demographics_filtered_validation_pattern.output, type=VALIDATION_TYPES),



# CRP data contain a smorgasbord of values that we need to clean.

rule data_demographics_cleaned_crp_discovery:
    output: 'tables/data/demographics/cleaned_crp/discovery/labs.feather'
    log: 'tables/data/demographics/cleaned_crp/discovery/labs.log'
    benchmark: 'tables/data/demographics/cleaned_crp/discovery/labs.txt'
    input: expand(rules.data_demographics_filtered_discovery_pattern.output, type='labs')
    version: v('scripts/data/demographics/clean_crp.py')
    shell:
        'python scripts/data/demographics/clean_crp.py --input {input} --output {output}' + LOG



# Clean the data.

rule data_demographics_cleaned_discovery_pattern:
    output: 'tables/data/demographics/cleaned/discovery/{type}.feather'
    log: 'tables/data/demographics/cleaned/discovery/{type}.log'
    benchmark: 'tables/data/demographics/cleaned/discovery/{type}.txt'
    input: lambda wildcards: 'tables/data/demographics/cleaned_crp/discovery/labs.feather' if wildcards.type == 'labs' else expand(rules.data_demographics_filtered_discovery_pattern.output, type=wildcards.type)
    version: v('scripts/data/demographics/clean_data.py')
    shell:
        'python scripts/data/demographics/clean_data.py --input {input} --output {output}' + LOG



rule data_demographics_cleaned_validation_pattern:
    output: 'tables/data/demographics/cleaned/validation/{type}.feather'
    log: 'tables/data/demographics/cleaned/validation/{type}.log'
    benchmark: 'tables/data/demographics/cleaned/validation/{type}.txt'
    input: rules.data_demographics_filtered_validation_pattern.output
    version: v('scripts/data/demographics/clean_data.py')
    shell:
        'python scripts/data/demographics/clean_data.py --input {input} --output {output}' + LOG



rule data_demographics_cleaned_discovery:
    input:
        expand(rules.data_demographics_cleaned_discovery_pattern.output, type=DISCOVERY_TYPES),



rule data_demographics_cleaned_validation:
    input:
        expand(rules.data_demographics_cleaned_validation_pattern.output, type=VALIDATION_TYPES),



rule data_demographics_cleaned:
    input:
        rules.data_demographics_cleaned_discovery.input,
        rules.data_demographics_cleaned_validation.input,



# Join all data together.

rule data_demographics_joined_discovery:
    output: 'tables/data/demographics/joined/discovery.feather'
    log: 'tables/data/demographics/joined/discovery.log'
    benchmark: 'tables/data/demographics/joined/discovery.txt'
    input: expand(rules.data_demographics_cleaned_discovery_pattern.output, type=DISCOVERY_TYPES)
    version: v('scripts/data/demographics/join_data.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/data/demographics/join_data.py {inputs} --output {output}' + LOG)



rule data_demographics_joined_validation:
    output: 'tables/data/demographics/joined/validation.feather'
    log: 'tables/data/demographics/joined/validation.log'
    benchmark: 'tables/data/demographics/joined/validation.txt'
    input: expand(rules.data_demographics_cleaned_validation_pattern.output, type=VALIDATION_TYPES)
    version: v('scripts/data/demographics/join_data.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/data/demographics/join_data.py {inputs} --output {output}' + LOG)



rule data_demographics_joined:
    input:
        expand('tables/data/demographics/joined/{cohort}.feather', cohort=COHORTS),



# Output the names of all columns.

rule data_demographics_column_names_pattern:
    output: 'tables/data/demographics/column_names/{cohort}.txt'
    log: 'tables/data/demographics/column_names/{cohort}.log'
    benchmark: 'tables/data/demographics/column_names/{cohort}.benchmark.txt'
    input: 'tables/data/demographics/joined/{cohort}.feather'
    version: v('scripts/data/demographics/get_columns.py')
    shell:
        'python scripts/data/demographics/get_columns.py --input {input} --output {output}' + LOG



rule data_demographics_column_names:
    input:
        expand(rules.data_demographics_column_names_pattern.output, cohort=COHORTS),



# Link outputs.

rule data_demographics_outputs_pattern:
    output: 'outputs/data/demographics/{cohort}.feather'
    input: 'tables/data/demographics/joined/{cohort}.feather'
    shell: LN



rule data_demographics_outputs:
    input:
        expand(rules.data_demographics_outputs_pattern.output, cohort=COHORTS),


# Targets.

rule data_demographics_tables:
    input:
        rules.data_demographics_inputs.input,
        rules.data_demographics_extracted.input,
        rules.data_demographics_filtered.input,
        rules.data_demographics_cleaned.input,
        rules.data_demographics_joined.input,
        rules.data_demographics_column_names.input,



rule data_demographics_parameters:
    input:



rule data_demographics_figures:
    input:



rule data_demographics:
    input:
        rules.data_demographics_inputs.input,
        rules.data_demographics_tables.input,
        rules.data_demographics_parameters.input,
        rules.data_demographics_figures.input,
        rules.data_demographics_outputs.input,