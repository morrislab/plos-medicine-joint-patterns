"""
Extracts diagnoses for the discovery cohort.
"""

VALIDATED_SITES = ['toronto', 'other']

BASICS_INPUT = 'inputs/diagnoses/discovery/basics.feather'
FILTER_INPUT = 'inputs/diagnoses/discovery/filter.csv'

TORONTO_INPUT = 'data/diagnosis_validation/Diagnosis- List of patients validated/List of patients validated DIAGNOSES TORONTO 12Jul12.xlsx'
OTHER_INPUT = 'data/diagnosis_validation/Diagnosis- List of patients validated/List of patients validated DIAGNOSES OTHER SITES 121012.xlsx'



# Link inputs.

rule diagnoses_discovery_inputs_basics:
    output: BASICS_INPUT
    input: 'outputs/data/discovery/basics.feather'
    shell: LN



rule diagnoses_discovery_inputs_filter:
    output: FILTER_INPUT
    input: 'outputs/data/discovery/filter.csv'
    shell: LN



rule diagnoses_discovery_inputs:
    input:
        BASICS_INPUT,
        FILTER_INPUT,



# Extract base diagnoses.

rule diagnoses_discovery_base_extracted:
    output: 'tables/diagnoses/discovery/base/extracted.csv'
    log: 'tables/diagnoses/discovery/base/extracted.log'
    benchmark: 'tables/diagnoses/discovery/base/extracted.txt'
    input: BASICS_INPUT
    version: v('scripts/diagnoses/discovery/base/extract.py')
    shell:
        'python scripts/diagnoses/discovery/base/extract.py --input {input} --output {output}' + LOG



rule diagnoses_discovery_base_filtered:
    output: 'tables/diagnoses/discovery/base/filtered.csv',
    log: 'tables/diagnoses/discovery/base/filtered.log',
    benchmark: 'tables/diagnoses/discovery/base/filtered.txt',
    input:
        filter=FILTER_INPUT,
        diagnoses=rules.diagnoses_discovery_base_extracted.output,
    version: v('scripts/diagnoses/discovery/base/filter.py')
    shell: 'python scripts/diagnoses/discovery/base/filter.py --diagnosis-input {input.diagnoses} --filter-input {input.filter} --output {output}' + LOG



# Extract validated diagnoses.

# Extract diagnoses.

rule diagnoses_discovery_validated_toronto:
    output: 'tables/diagnoses/discovery/validated/toronto.csv'
    log: 'tables/diagnoses/discovery/validated/toronto.log'
    benchmark: 'tables/diagnoses/discovery/validated/toronto.txt'
    input: TORONTO_INPUT
    version: v('scripts/diagnoses/discovery/validated/get_diagnoses.py')
    shell:
        'python scripts/diagnoses/discovery/validated/get_diagnoses.py --input {input:q} --output {output}' + LOG



rule diagnoses_discovery_validated_other:
    output: 'tables/diagnoses/discovery/validated/other.csv'
    log: 'tables/diagnoses/discovery/validated/other.log'
    benchmark: 'tables/diagnoses/discovery/validated/other.txt'
    input: OTHER_INPUT
    version: v('scripts/diagnoses/discovery/validated/get_diagnoses.py')
    shell:
        'python scripts/diagnoses/discovery/validated/get_diagnoses.py --input {input:q} --output {output}' + LOG



rule diagnoses_discovery_validated_merged:
    output: 'tables/diagnoses/discovery/validated/merged.csv'
    input: expand('tables/diagnoses/discovery/validated/{site}.csv', site=VALIDATED_SITES)
    shell:
        'cat {input[0]} > {output} && tail -n +2 {input[1]} >> {output}'



# Merge diagnoses together, with priority to validated diagnoses.

rule diagnoses_discovery_merged:
    output: 'tables/diagnoses/discovery/merged.csv'
    log: 'tables/diagnoses/discovery/merged.log'
    benchmark: 'tables/diagnoses/discovery/merged.txt'
    input:
        original=rules.diagnoses_discovery_base_filtered.output,
        validated=rules.diagnoses_discovery_validated_merged.output,
    version: v('scripts/diagnoses/merge_diagnoses.py')
    shell:
        'python scripts/diagnoses/merge_diagnoses.py --original-input {input.original} --validated-input {input.validated} --output {output}' + LOG



rule diagnoses_discovery_merged_all:
    output: 'tables/diagnoses/discovery/merged_all.csv'
    log: 'tables/diagnoses/discovery/merged_all.log'
    benchmark: 'tables/diagnoses/discovery/merged_all.txt'
    input:
        original=rules.diagnoses_discovery_base_extracted.output,
        validated=rules.diagnoses_discovery_validated_merged.output,
    version: v('scripts/diagnoses/merge_diagnoses.py')
    shell:
        'python scripts/diagnoses/merge_diagnoses.py --original-input {input.original} --validated-input {input.validated} --output {output}' + LOG



# Modify diagnoses to use 6-month diagnoses.

rule diagnoses_discovery_6_months:
    output: 'tables/diagnoses/discovery/6_months.csv'
    log: 'tables/diagnoses/discovery/6_months.log'
    benchmark: 'tables/diagnoses/discovery/6_months.txt'
    input: rules.diagnoses_discovery_merged.output
    version: v('scripts/diagnoses/discovery/extract_6_months.py')
    shell:
        'python scripts/diagnoses/discovery/extract_6_months.py --input {input} --output {output}' + LOG



rule diagnoses_discovery_6_months_all:
    output: 'tables/diagnoses/discovery/6_months_all.csv'
    log: 'tables/diagnoses/discovery/6_months_all.log'
    benchmark: 'tables/diagnoses/discovery/6_months_all.txt'
    input: rules.diagnoses_discovery_merged_all.output
    version: v('scripts/diagnoses/discovery/extract_6_months.py')
    shell:
        'python scripts/diagnoses/discovery/extract_6_months.py --input {input} --output {output}' + LOG



# Link outputs.

rule diagnoses_discovery_outputs_diagnoses:
    output: 'outputs/diagnoses/discovery.csv'
    input: rules.diagnoses_discovery_6_months.output
    shell: LN



rule diagnoses_discovery_outputs_diagnoses_all:
    output: 'outputs/diagnoses/discovery_all.csv'
    input: rules.diagnoses_discovery_6_months_all.output
    shell: LN



rule diagnoses_discovery_outputs:
    input:
        rules.diagnoses_discovery_outputs_diagnoses.output,
        rules.diagnoses_discovery_outputs_diagnoses_all.output,



# Targets.

rule diagnoses_discovery_tables:
    input:
        rules.diagnoses_discovery_base_extracted.output,
        rules.diagnoses_discovery_base_filtered.output,
        rules.diagnoses_discovery_validated_merged.output,
        rules.diagnoses_discovery_merged.output,
        rules.diagnoses_discovery_merged_all.output,
        rules.diagnoses_discovery_6_months.output,
        rules.diagnoses_discovery_6_months_all.output,



rule diagnoses_discovery_parameters:
    input:



rule diagnoses_discovery_figures:
    input:



rule diagnoses_discovery:
    input:
        rules.diagnoses_discovery_inputs.input,
        rules.diagnoses_discovery_tables.input,
        rules.diagnoses_discovery_parameters.input,
        rules.diagnoses_discovery_figures.input,
        rules.diagnoses_discovery_outputs.input,
