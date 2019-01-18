"""
Generates reports for demographics.
"""

DATA_INPUT = 'inputs/demographics/data/{cohort}.feather'
DIAGNOSIS_INPUT = 'inputs/demographics/diagnoses/{cohort}.csv'
JOINTS_INPUT = 'inputs/demographics/joints/{cohort}.csv'



# Link inputs.

rule demographics_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/demographics/{cohort}.feather'
    shell: LN



rule demographics_inputs_diagnoses_pattern:
    output: DIAGNOSIS_INPUT
    input: 'outputs/diagnoses/{cohort}.csv'
    shell: LN



rule demographics_inputs_joints_pattern:
    output: JOINTS_INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule demographics_inputs:
    input:
        expand(DATA_INPUT, cohort=COHORTS),



# Generate reports.

rule demographics_discovery:
    output: 'tables/demographics/discovery.html'
    log: 'tables/demographics/discovery.log'
    benchmark: 'tables/demographics/discovery.txt'
    input:
        data=expand(DATA_INPUT, cohort='discovery'),
        diagnoses=expand(DIAGNOSIS_INPUT, cohort='discovery'),
        joints=expand(JOINTS_INPUT, cohort='discovery'),
    params:
        columns='diagnosis patient_basics_diagnosis_age patient_basics_symptom_onset_to_diagnosis patient_basics_sex num_active_joints chaq_chaq_correct_score jaqq_jaqq_score qoml_health labs_haem_res labs_platelet_res labs_wbc_res labs_esr_res labs_crp_res labs_ana_res labs_rf_1_res labs_rf_2_res labs_b27_res examinations_pgada'.split(),
    version: v('scripts/demographics/get_demographics.R')
    shell:
        'Rscript scripts/demographics/get_demographics.R --data-input {input.data} --joint-input {input.joints} --diagnosis-input {input.diagnoses} --output {output} --columns {params.columns}' + LOG



rule demographics_validation:
    output: 'tables/demographics/validation.html'
    log: 'tables/demographics/validation.log'
    benchmark: 'tables/demographics/validation.txt'
    input:
        data=expand(DATA_INPUT, cohort='validation'),
        diagnoses=expand(DIAGNOSIS_INPUT, cohort='validation'),
        joints=expand(JOINTS_INPUT, cohort='validation'),
    params:
        columns='diagnosis num_active_joints all_rfp all_anap all_hlap all_hgb all_plt all_esr1 all_crp1 all_sex all_yage_diag all_dsymp_diagn'.split(),
    version: v('scripts/demographics/get_demographics.R')
    shell:
        'Rscript scripts/demographics/get_demographics.R --data-input {input.data} --joint-input {input.joints} --diagnosis-input {input.diagnoses} --output {output} --columns {params.columns}' + LOG



# Targets.

rule demographics_tables:
    input:
        rules.demographics_discovery.output,
        rules.demographics_validation.output,



rule demographics_parameters:
    input:



rule demographics_figures:
    input:



rule demographics:
    input:
        rules.demographics_inputs.input,
        rules.demographics_tables.input,
        rules.demographics_parameters.input,
        rules.demographics_figures.input,
