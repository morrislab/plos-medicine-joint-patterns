"""
Filtered data for the paper.
"""

ALL_COHORTS = ['discovery', 'validation']



# Basic data.

rule data_paper_basics_discovery:
    output: 'tables/data/paper/basics/discovery.csv'
    log: 'tables/data/paper/basics/discovery.log'
    benchmark: 'tables/data/paper/basics/discovery.txt'
    input:
        diagnoses='tables/diagnoses/6_months/discovery.csv',
        data='tables/discovery/data/patient_basics.feather',
    version: v('scripts/data/paper/filter_data.py')
    shell:
        'python scripts/data/paper/filter_data.py --diagnosis-input {input.diagnoses} --data-input {input.data} --output {output}' + LOG



rule data_paper_basics_validation:
    output: 'tables/data/paper/basics/validation.csv'
    log: 'tables/data/paper/basics/validation.log'
    benchmark: 'tables/data/paper/basics/validation.txt'
    input:
        diagnoses='tables/diagnoses/validation.csv',
        data='tables/validation/data/extracted/basics.feather',
    version: v('scripts/data/paper/filter_data.py')
    shell:
        'python scripts/data/paper/filter_data.py --diagnosis-input {input.diagnoses} --data-input {input.data} --output {output}' + LOG



rule data_paper_basics:
    input:
        expand('tables/data/paper/basics/{cohort}.csv', cohort=ALL_COHORTS),



# Targets.

rule data_paper_tables:
    input:
        rules.data_paper_basics.input,



rule data_paper_figures:
    input:



rule data_paper:
    input:
        rules.data_paper_tables.input,
        rules.data_paper_figures.input,