"""
Compares ILAR subtypes between the discovery and validation cohorts.
"""

INPUT = 'inputs/diagnoses/comparison/{cohort}.csv'



# Link inputs.

rule diagnoses_comparison_inputs_pattern:
    output: INPUT
    input: 'outputs/diagnoses/{cohort}.csv'
    shell: LN



rule diagnoses_comparison_inputs:
    input:
        INPUT,



# Compares ILAR subtypes between the discovery and validation cohorts.

rule diagnoses_comparison_stats:
    output: 'tables/diagnoses/comparison/stats.txt'
    log: 'tables/diagnoses/comparison/stats.log'
    benchmark: 'tables/diagnoses/comparison/stats.benchmark.txt'
    input:
        discovery=expand(INPUT, cohort='discovery'),
        validation=expand(INPUT, cohort='validation'),
    version: v('scripts/diagnoses/compare_diagnoses.R')
    shell:
        'Rscript scripts/diagnoses/compare_diagnoses.R --discovery-input {input.discovery} --validation-input {input.validation} --output {output}' + LOG



# Link outputs.

rule diagnoses_comparison_outputs:
    input:



# Targets.

rule diagnoses_comparison_tables:
    input:
        rules.diagnoses_comparison_stats.output,



rule diagnoses_comparison_parameters:
    input:



rule diagnoses_comparison_figures:
    input:



rule diagnoses_comparison:
    input:
        rules.diagnoses_comparison_inputs.input,
        rules.diagnoses_comparison_tables.input,
        rules.diagnoses_comparison_parameters.input,
        rules.diagnoses_comparison_figures.input,
        rules.diagnoses_comparison_outputs.input,
