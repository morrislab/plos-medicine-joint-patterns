# Validation data.
"""
Generates data for the validation cohort.
"""

SOURCE_DIR = config.data.source_dirs.validation
INPUT = join(SOURCE_DIR, '{file}')
ALL_INPUT = expand(INPUT, file='all_data.xls')
FINAL_INPUT = expand(INPUT, file='final_data.xls')
JOINTS_INPUT = expand(INPUT, file='joints.xls')

VISITS = config.data.visits.validation
VISITS_STR = [f'{x:02d}' for x in VISITS]



# Link inputs.

rule data_validation_inputs_all_data:
    output: ALL_INPUT
    input: join(SOURCE_DIR, 'All Data June 10 2014.xls')
    shell: LN



rule data_validation_inputs_final_data:
    output: FINAL_INPUT
    input: join(SOURCE_DIR, 'Final data.xls')
    shell: LN



rule data_validation_inputs_joints:
    output: JOINTS_INPUT
    input: join(SOURCE_DIR, 'extracted/Visits.xls')
    shell: LN



rule data_validation_inputs:
    input:
        expand(INPUT, file=['all_data.xls', 'final_data.xls', 'joints.xls']),



# Extract raw data.

rule data_validation_basics:
    output: 'tables/data/validation/extracted/basics.feather'
    log: 'tables/data/validation/extracted/basics.log'
    benchmark: 'tables/data/validation/extracted/basics.txt'
    input: ALL_INPUT
    version: v('scripts/data/validation/extract_basics.py')
    shell:
        'python scripts/data/validation/extract_basics.py --input {input:q} --output {output}' + LOG



rule data_validation_medications:
    output: 'tables/data/validation/extracted/medications.feather'
    log: 'tables/data/validation/extracted/medications.log'
    benchmark: 'tables/data/validation/extracted/medications.txt'
    input: FINAL_INPUT
    params:
        visit_id=1,
    version: v('scripts/data/validation/extract_medications.py')
    shell:
        'python scripts/data/validation/extract_medications.py --input "{input}" --output {output} --visit {params.visit_id}' + LOG



# rule data_validation_medications_all:
#     output: 'tables/data/validation/extracted/medications_all.feather'
#     log: 'tables/data/validation/extracted/medications_all.log'
#     benchmark: 'tables/data/validation/extracted/medications_all.txt'
#     input: expand('{prefix}/Final data.xls', prefix=SOURCE_DIR)
#     version: v('scripts/data/validation/extract_medications_all.py')
#     shell:
#         'python scripts/data/validation/extract_medications_all.py --input {input:q} --output {output}' + LOG



rule data_validation_sites_pattern:
    output: 'tables/data/validation/extracted/visit_{visit}.feather'
    log: 'tables/data/validation/extracted/visit_{visit}.log'
    benchmark: 'tables/data/validation/extracted/visit_{visit}.txt'
    input: JOINTS_INPUT
    version: v('scripts/data/validation/extract_sites.py')
    shell:
        'python scripts/data/validation/extract_sites.py --input {input:q} --output {output} --visit {wildcards.visit}' + LOG



rule data_validation_sites:
    input:
        expand(rules.data_validation_sites_pattern.output, visit=VISITS_STR),



# Filtered data.

rule data_validation_filter:
    output: 'tables/data/validation/filtered/filter.csv'
    log: 'tables/data/validation/filtered/filter.log'
    benchmark: 'tables/data/validation/filtered/filter.txt'
    input:
        basics=rules.data_validation_basics.output,
        medications=rules.data_validation_medications.output,
        sites=expand(rules.data_validation_sites_pattern.output, visit='01'),
    params:
        age_of_onset=5840,
        onset_to_diagnosis=91,
    version: v('scripts/data/validation/get_filter.py')
    shell:
        'python scripts/data/validation/get_filter.py --basics-input {input.basics} --medications-input {input.medications} --sites-input {input.sites} --output {output} --age-of-symptom-onset {params.age_of_onset} --symptom-onset-to-diagnosis {params.onset_to_diagnosis}' + LOG



rule data_validation_filtered_pattern:
    output: 'tables/data/validation/filtered/visit_{visit}.csv'
    log: 'tables/data/validation/filtered/visit_{visit}.log'
    benchmark: 'tables/data/validation/filtered/visit_{visit}.txt'
    input:
        sites=rules.data_validation_sites_pattern.output,
        filter=rules.data_validation_filter.output,
    version: v('scripts/data/validation/filter.py')
    shell:
        'python scripts/data/validation/filter.py --sites-input {input.sites} --filter-input {input.filter} --output {output}' + LOG



rule data_validation_filtered:
    input:
        expand(rules.data_validation_filtered_pattern.output, visit=VISITS_STR),



# For projections onto the discovery factors, concatenate and align the data.

rule data_validation_concatenated:
    output: 'tables/data/validation/concatenated/data.csv'
    log: 'tables/data/validation/concatenated/data.log'
    benchmark: 'tables/data/validation/concatenated/data.txt'
    input: expand(rules.data_validation_filtered_pattern.output, visit=VISITS_STR)
    params:
        visits=VISITS
    version: v('scripts/data/validation/concatenate.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        visits = ' '.join(f'--visit {x}' for x in params.visits)
        shell('python scripts/data/validation/concatenate.py {inputs} {visits} --output {output}' + LOG)



rule data_validation_aligned:
    output: 'tables/data/validation/aligned/data.feather'
    log: 'tables/data/validation/aligned/data.log'
    benchmark: 'tables/data/validation/aligned/data.txt'
    input:
        'tables/data/discovery/filtered/filtered.done',
        validation=rules.data_validation_concatenated.output,
        discovery='tables/data/discovery/filtered/data.feather',
    version: v('scripts/data/validation/align_to_discovery.py')
    shell:
        'python scripts/data/validation/align_to_discovery.py --validation-input {input.validation} --discovery-input {input.discovery} --output {output}' + LOG



# Remove useless sites for independent validation.

rule data_validation_selected_visit_1:
    output: 'tables/data/validation/selected/visit_01.csv'
    log: 'tables/data/validation/selected/visit_01.log'
    benchmark: 'tables/data/validation/selected/visit_01.txt'
    input: expand(rules.data_validation_filtered_pattern.output, visit='01')
    version: v('scripts/data/select_useful_data.py')
    shell:
        'python scripts/data/select_useful_data.py --input {input} --output {output}' + LOG



rule data_validation_selected_pattern:
    output: 'tables/data/validation/selected/visit_{visit}.csv'
    log: 'tables/data/validation/selected/visit_{visit}.log'
    benchmark: 'tables/data/validation/selected/visit_{visit}.txt'
    input:
        reference=rules.data_validation_selected_visit_1.output,
        data=rules.data_validation_filtered_pattern.output,
    version: v('scripts/data/select_data_from_reference.py')
    shell:
        'python scripts/data/select_data_from_reference.py --reference-input {input.reference} --data-input {input.data} --output {output}' + LOG



ruleorder: data_validation_selected_visit_1 > data_validation_selected_pattern



rule data_validation_selected_target:
    input:
        expand('tables/data/validation/selected/visit_{visit}.csv', visit=VISITS_STR),



rule data_validation_selected:
    output: 'tables/data/validation/selected/data.csv'
    input: rules.data_validation_selected_visit_1.output
    shell: LN



# Link outputs.

rule data_validation_outputs_basics:
    output: 'outputs/data/validation/basics.feather'
    input: rules.data_validation_basics.output
    shell: LN



rule data_validation_outputs_joints_pattern:
    output: 'outputs/data/validation/joints/visit_{visit}.csv'
    input: 'tables/data/validation/selected/visit_{visit}.csv'
    shell: LN



rule data_validation_outputs_joints_baseline:
    output: 'outputs/data/validation/joints.csv'
    input: 'tables/data/validation/selected/visit_01.csv'
    shell: LN



rule data_validation_outputs_joints:
    input:
        rules.data_validation_outputs_basics.output,
        expand(rules.data_validation_outputs_joints_pattern.output, visit=VISITS_STR),
        rules.data_validation_outputs_joints_baseline.output,



rule data_validation_outputs_joints_feather:
    output: 'outputs/data/validation/joints.feather'
    input: rules.data_validation_aligned.output
    shell: LN



rule data_validation_outputs:
    input:
        rules.data_validation_outputs_basics.output,
        rules.data_validation_outputs_joints.input,
        rules.data_validation_outputs_joints_feather.output,



# Targets.

rule data_validation_tables:
    input:
        rules.data_validation_basics.output,
        rules.data_validation_medications.output,
        rules.data_validation_sites.input,
        rules.data_validation_filter.output,
        rules.data_validation_filtered.input,
        rules.data_validation_concatenated.output,
        rules.data_validation_selected_target.input,
        rules.data_validation_selected.output,
        rules.data_validation_aligned.output,



rule data_validation_parameters:
    input:



rule data_validation_figures:
    input:



rule data_validation:
    input:
        rules.data_validation_inputs.input,
        rules.data_validation_tables.input,
        rules.data_validation_parameters.input,
        rules.data_validation_figures.input,
        rules.data_validation_outputs.input,
