"""
Generates key sites per factor.
"""

LEVELS = config.representative_sites.levels

INPUT = 'inputs/representative_sites/bases/{cohort}/{level}.csv'



# Link inputs.

rule representative_sites_inputs_l1_pattern:
    output: 'inputs/representative_sites/bases/{cohort}/l1.csv'
    input: 'outputs/nmf/{cohort}/l1/model/basis.csv'
    shell: LN



rule representative_sites_inputs_pattern:
    output: INPUT
    input: 'outputs/combined_bases/{cohort}/{level}.csv'
    shell: LN



rule representative_sites_inputs:
    input:
        expand(INPUT, cohort=COHORTS, level=LEVELS),



# Calculate key sites.

rule representative_sites_sites_pattern:
    output: 'tables/representative_sites/{cohort}/{level}.csv'
    log: 'tables/representative_sites/{cohort}/{level}.log'
    benchmark: 'tables/representative_sites/{cohort}/{level}.txt'
    input: INPUT
    version: v('scripts/representative_sites/get_representative_sites.py')
    shell:
        'python scripts/representative_sites/get_representative_sites.py --input {input} --output {output} --letters' + LOG



rule representative_sites_sites:
    input:
        expand(rules.representative_sites_sites_pattern.output, cohort=COHORTS, level=LEVELS),



# Link outputs.

rule representative_sites_outputs_pattern:
    output: 'outputs/representative_sites/{cohort}/{level}.csv'
    input: rules.representative_sites_sites_pattern.output
    shell: LN



rule representative_sites_outputs:
    input:
        expand(rules.representative_sites_outputs_pattern.output, cohort=COHORTS, level=LEVELS),



# Targets.

rule representative_sites_tables:
    input:
        rules.representative_sites_sites.input,



rule representative_sites_parameters:
    input:



rule representative_sites_figures:
    input:



rule representative_sites:
    input:
        rules.representative_sites_inputs.input,
        rules.representative_sites_tables.input,
        rules.representative_sites_parameters.input,
        rules.representative_sites_figures.input,
        rules.representative_sites_outputs.input,