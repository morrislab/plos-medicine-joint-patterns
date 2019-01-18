"""
Generates data for the discovery cohort.
"""

SOURCE_DIR = config.data.source_dirs.discovery
DOMAINS = ['CHAQ', 'ENTHESITIS', 'EXAMINATIONS', 'HISTORY_ENROLMENT', 'HISTORY_FOLLOW_UP', 'INTERIM_LABS_PGADA', 'JAQQ', 'JOINT_INJECTIONS', 'JOINTS', 'LABS', 'MEDICATIONS', 'QoML', 'SOCIAL_FAMILY']
VISITS = config.data.visits.discovery
DOMAIN_INPUT = 'inputs/data/discovery/{domain}.xls'
PATIENT_BASICS_INPUT = expand(DOMAIN_INPUT, domain='PATIENT_BASICS')



# Link inputs.

rule data_discovery_inputs_patient_basics:
    output: PATIENT_BASICS_INPUT
    input: join(SOURCE_DIR, 'master_files/PATIENT_BASICS.xls')
    shell: LN



rule data_discovery_inputs_pattern:
    output: DOMAIN_INPUT
    input: join(SOURCE_DIR, 'primary_data_files/{domain}.xls')
    shell: LN



rule data_discovery_inputs:
    input:
        expand(DOMAIN_INPUT, domain=DOMAINS + ['PATIENT_BASICS']),



# Generate information about the original Excel files.

rule data_discovery_information:
    output: 'tables/data/discovery/columns.yaml'
    log: 'tables/data/discovery/columns.log'
    benchmark: 'tables/data/discovery/columns.txt'
    input:
        basics=expand(DOMAIN_INPUT, domain='PATIENT_BASICS'),
        primary_data_files=expand(DOMAIN_INPUT, domain=DOMAINS),
    version: v('scripts/data/get_info.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in [input.basics] + input.primary_data_files)
        shell('python scripts/data/get_info.py {inputs} --output {output}' + LOG)



# Extract information for filtering the patient cohort.

rule data_discovery_basics:
    output: 'tables/data/discovery/patient_basics.feather'
    log: 'tables/data/discovery/patient_basics.log'
    benchmark: 'tables/data/discovery/patient_basics.txt'
    input: PATIENT_BASICS_INPUT
    version: v('scripts/data/discovery/extract_patient_basics.py')
    shell:
        'python scripts/data/discovery/extract_patient_basics.py --input {input} --output {output}' + LOG



rule data_discovery_medications:
    output: 'tables/data/discovery/medications.feather'
    log: 'tables/data/discovery/medications.log'
    benchmark: 'tables/data/discovery/medications.txt'
    input: expand(DOMAIN_INPUT, domain='MEDICATIONS')
    version: v('scripts/data/discovery/extract_medication_summaries.py')
    shell:
        'python scripts/data/discovery/extract_medication_summaries.py --input {input} --output {output}' + LOG



rule data_discovery_joint_injections:
    output: 'tables/data/discovery/joint_injections.feather'
    log: 'tables/data/discovery/joint_injections.log'
    benchmark: 'tables/data/discovery/joint_injections.txt'
    input: expand(DOMAIN_INPUT, domain='JOINT_INJECTIONS')
    version: v('scripts/data/discovery/extract_joint_injections.py')
    shell:
        'python scripts/data/discovery/extract_joint_injections.py --input {input} --output {output}' + LOG



rule data_discovery_joints:
    output: 'tables/data/discovery/joints.feather'
    log: 'tables/data/discovery/joints.feather'
    benchmark: 'tables/data/discovery/joints.txt'
    input: expand(DOMAIN_INPUT, domain='JOINTS')
    version: v('scripts/data/discovery/extract_joint_information.py') + LOG
    shell:
        'python scripts/data/discovery/extract_joint_information.py --input {input} --output {output}' + LOG



rule data_discovery_enthesitis:
    output: 'tables/data/discovery/enthesitis.feather'
    log: 'tables/data/discovery/enthesitis.log'
    benchmark: 'tables/data/discovery/enthesitis.txt'
    input: expand(DOMAIN_INPUT, domain='ENTHESITIS')
    version:
        v('scripts/data/discovery/extract_enthesitis_information.py')
    shell:
        'python scripts/data/discovery/extract_enthesitis_information.py --input {input} --output {output}' + LOG



# Filter the data to treatment-naive patients with joint involvement at baseline who
# were diagnosed no more than one year after symptom onset.

rule data_discovery_filtered:
    output:
        data='tables/data/discovery/filtered/data.feather',
        filter='tables/data/discovery/filtered/filter.csv',
        flag=touch('tables/data/discovery/filtered/filtered.done'),
    log: 'tables/data/discovery/filtered/filtered.log'
    benchmark: 'tables/data/discovery/filtered/filtered.txt'
    input:
        basic=rules.data_discovery_basics.output,
        medications=rules.data_discovery_medications.output,
        joint_injections=rules.data_discovery_joint_injections.output,
        joints=rules.data_discovery_joints.output,
    version: v('scripts/data/discovery/filter_joint_data.py')
    shell:
        'python scripts/data/discovery/filter_joint_data.py --basic-input {input.basic} --medication-input {input.medications} --joint-injection-input {input.joint_injections} --joint-input {input.joints} --output {output.data} --filter-output {output.filter}' + LOG



# Split data by visit.

rule data_discovery_split:
    output:
        data=expand('tables/data/discovery/split/data_{x:02d}.csv', x=VISITS),
        flag=touch('tables/data/discovery/split/split.done'),
    input:
        rules.data_discovery_filtered.output.flag,
        data=rules.data_discovery_filtered.output.data,
    params:
        prefix='tables/data/discovery/split/data_',
    version: v('scripts/data/discovery/split_data.py')
    shell:
        'python scripts/data/discovery/split_data.py --input {input.data} --output-prefix {params.prefix}' + LOG



# Extract core set data.

rule data_discovery_core_set:
    output: 'tables/data/discovery/core_set/data.feather'
    log: 'tables/data/discovery/core_set/data.log'
    benchmark: 'tables/data/discovery/core_set/data.txt'
    input:
        field_map='data/core_set/field_map.yaml',
        basics=PATIENT_BASICS_INPUT,
        primary_data_files=expand(DOMAIN_INPUT, domain=['CHAQ', 'ENTHESITIS', 'EXAMINATIONS', 'JOINTS', 'JAQQ', 'LABS', 'QoML']),
    version: v('scripts/data/discovery/extract_variables.py')
    run:
        data_inputs = ' '.join(f'--data-input {x}' for x in [input.basics] + input.primary_data_files)
        shell('python scripts/data/discovery/extract_variables.py --field-map-input {input.field_map} {data_inputs} --output {output}' + LOG)



rule data_discovery_core_set_filled_enthesitis:
    output: 'tables/data/discovery/core_set/filled_enthesitis.feather'
    log: 'tables/data/discovery/core_set/filled_enthesitis.log'
    benchmark: 'tables/data/discovery/core_set/filled_enthesitis.txt'
    input: rules.data_discovery_core_set.output
    version: v('scripts/data/discovery/core_set/fill_enthesitis.py')
    shell:
        'python scripts/data/discovery/core_set/fill_enthesitis.py --input {input} --output {output}' + LOG



rule data_discovery_core_set_transformed:
    output: 'tables/data/discovery/core_set/transformed.feather'
    log: 'tables/data/discovery/core_set/transformed.log'
    benchmark: 'tables/data/discovery/core_set/transformed.txt'
    input:
        type_map='data/core_set/type_map.yaml',
        data=rules.data_discovery_core_set_filled_enthesitis.output,
    version: v('scripts/data/transform_variables.py')
    shell:
        'python scripts/data/transform_variables.py --type-map-input {input.type_map} --data-input {input.data} --output {output}' + LOG



# Extract data used to generate the disease activity indicator.
# Number of effused joints: ---
# Number of joints w/LROM: JOINTS.xls -> NUM_ROM_JOINTS
# Number of active joints: JOINTS.xls -> TOTAL_JOINTS
# CHAQ: CHAQ.xls -> CHAQ_correct_score
# JAQQ: JAQQ.xls -> JAQQ_score
# Patient VAS: CHAQ.xls -> PAIN_VAS
# PGADA: EXAMINATIONS.xls -> PGA
# QoML Considering My Health: QoML.xls -> health
# Sex: PATIENT_BASICS.xls -> SEX
# ESR: LABS.xls -> ESR_RES
# Hemoglobin: LABS.xls -> HAEM_RES
# Platelets: LABS.xls -> PLATELET_RES
# ANA: LABS.xls -> ANA_RES
# CRP: LABS.xls -> CRP_RES

rule data_discovery_dai_data:
    output: 'tables/data/discovery/dai/data/discovery.feather'
    log: 'tables/data/discovery/dai/data/discovery.log'
    benchmark: 'tables/data/discovery/dai/data/discovery.txt'
    input:
        field_map='data/dai/field_map.yaml',
        basics=PATIENT_BASICS_INPUT,
        primary_data_files=expand(DOMAIN_INPUT, domain=['CHAQ', 'EXAMINATIONS', 'JOINTS', 'JAQQ', 'LABS', 'QoML'])
    version: v('scripts/data/discovery/extract_variables.py')
    run:
        inputs = ' '.join(f'--data-input {x}' for x in [input.basics] + input.primary_data_files)
        shell('python scripts/data/discovery/extract_variables.py --field-map-input {input.field_map} {inputs} --output {output}' + LOG)



rule data_discovery_dai_transformed:
    output: 'tables/data/discovery/dai/transformed.feather'
    log: 'tables/data/discovery/dai/transformed.log'
    benchmark: 'tables/data/discovery/dai/transformed.txt'
    input:
        type_map='data/dai/type_map.yaml',
        data=rules.data_discovery_dai_data.output,
    version: v('scripts/data/transform_variables.py')
    shell:
        'python scripts/data/transform_variables.py --type-map-input {input.type_map} --data-input {input.data} --output {output}' + LOG



rule data_discovery_dai_projections:
    output: 'tables/data/discovery/dai/scores.csv'
    log: 'tables/data/discovery/dai/scores.log'
    benchmark: 'tables/data/discovery/dai/scores.txt'
    input:
        original_prescaled='data/previous_studies/clinical_cytokines/prescaled_reference_data/data.csv',
        original_loadings='data/previous_studies/clinical_cytokines/pca/loadings.csv',
        measurements=rules.data_discovery_dai_transformed.output,
    version: v('scripts/data/discovery/dai/project_to_dai.py')
    shell:
        'python scripts/data/discovery/dai/project_to_dai.py --original-prescaled-input {input.original_prescaled} --original-loading-input {input.original_loadings} --measurement-input {input.measurements} --output {output}' + LOG



# Link outputs.

rule data_discovery_outputs_basics:
    output: 'outputs/data/discovery/basics.feather'
    input: rules.data_discovery_basics.output
    shell: LN



rule data_discovery_outputs_medications:
    output: 'outputs/data/discovery/medications.feather'
    input: rules.data_discovery_medications.output
    shell: LN



rule data_discovery_outputs_joint_injections:
    output: 'outputs/data/discovery/joint_injections.feather'
    input: rules.data_discovery_joint_injections.output
    shell: LN



rule data_discovery_outputs_joints_feather:
    output: 'outputs/data/discovery/joints.feather'
    input: rules.data_discovery_joints.output
    shell: LN



rule data_discovery_outputs_filter:
    output: 'outputs/data/discovery/filter.csv'
    input:
        rules.data_discovery_filtered.output.flag,
        input=rules.data_discovery_filtered.output.filter,
    shell: LN_ALT



rule data_discovery_outputs_filtered:
    output: 'outputs/data/discovery/filtered.feather'
    input:
        rules.data_discovery_filtered.output.flag,
        input=rules.data_discovery_filtered.output.data,
    shell: LN_ALT



rule data_discovery_outputs_joints_pattern:
    output: 'outputs/data/discovery/joints/visit_{visit}.csv'
    input:
        rules.data_discovery_split.output.flag,
        input='tables/data/discovery/split/data_{visit}.csv',
    shell: LN_ALT



rule data_discovery_outputs_joints_baseline:
    output: 'outputs/data/discovery/joints.csv'
    input:
        rules.data_discovery_split.output.flag,
        input='tables/data/discovery/split/data_01.csv',
    shell: LN_ALT



rule data_discovery_outputs_joints:
    input:
        expand('outputs/data/discovery/joints/visit_{visit:02d}.csv', visit=VISITS),
        rules.data_discovery_outputs_joints_baseline.output,



rule data_discovery_outputs_core_set:
    output: 'outputs/data/discovery/core_set.feather'
    input: rules.data_discovery_core_set_transformed.output
    shell: LN



rule data_discovery_outputs_dai_scores:
    output: 'outputs/data/discovery/dai_scores.csv'
    input: rules.data_discovery_dai_projections.output
    shell: LN



rule data_discovery_outputs:
    input:
        rules.data_discovery_outputs_joints.input,
        expand('outputs/data/discovery/{path}', path=['basics.feather', 'medications.feather', 'joint_injections.feather', 'filter.csv', 'filtered.feather', 'core_set.feather', 'dai_scores.csv']),



# Targets.

rule data_discovery_tables:
    input:
        rules.data_discovery_information.output,
        rules.data_discovery_basics.output,
        rules.data_discovery_medications.output,
        rules.data_discovery_joint_injections.output,
        rules.data_discovery_joints.output,
        rules.data_discovery_enthesitis.output,
        rules.data_discovery_filtered.output,
        rules.data_discovery_split.output,
        rules.data_discovery_dai_data.output,
        rules.data_discovery_dai_transformed.output,
        rules.data_discovery_dai_projections.output,
        rules.data_discovery_core_set.output,
        rules.data_discovery_core_set_filled_enthesitis.output,
        rules.data_discovery_core_set_transformed.output



rule data_discovery_parameters:
    input:



rule data_discovery_figures:
    input:



rule data_discovery:
    input:
        rules.data_discovery_inputs.input,
        rules.data_discovery_tables.input,
        rules.data_discovery_parameters.input,
        rules.data_discovery_figures.input,
        rules.data_discovery_outputs.input,
