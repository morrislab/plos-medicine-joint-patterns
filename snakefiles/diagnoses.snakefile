# Diagnoses.

include: 'diagnoses/discovery.snakefile'
include: 'diagnoses/validation.snakefile'
include: 'diagnoses/comparison.snakefile'
include: 'diagnoses/inclusion_counts.snakefile'



# Trim diagnoses to roots.

rule diagnoses_roots_pattern:
    output: 'tables/diagnoses/roots/{cohort}.csv'
    input: 'outputs/diagnoses/{cohort}.csv'
    shell:
        '''cut -d',' -f1-2 {input} > {output}'''



rule diagnoses_roots:
    input:
        expand(rules.diagnoses_roots_pattern.output, cohort=['discovery', 'validation']),



# Link outputs.

rule diagnoses_outputs_roots_pattern:
    output: 'outputs/diagnoses/roots/{cohort}.csv'
    input: rules.diagnoses_roots_pattern.output
    shell: LN



rule diagnoses_outputs_roots:
    input:
        expand(rules.diagnoses_outputs_roots_pattern.output, cohort=COHORTS),



rule diagnoses_outputs:
    input:
        rules.diagnoses_discovery_outputs.input,
        rules.diagnoses_validation_outputs.input,
        rules.diagnoses_comparison_outputs.input,
        rules.diagnoses_inclusion_counts_outputs.input,
        rules.diagnoses_outputs_roots.input,



# Targets.

rule diagnoses_tables:
    input:
        rules.diagnoses_discovery_tables.input,
        rules.diagnoses_validation_tables.input,
        rules.diagnoses_comparison_tables.input,
        rules.diagnoses_inclusion_counts_tables.input,
        rules.diagnoses_roots.input,



rule diagnoses_parameters:
    input:
        rules.diagnoses_discovery_parameters.input,
        rules.diagnoses_validation_parameters.input,
        rules.diagnoses_comparison_parameters.input,
        rules.diagnoses_inclusion_counts_parameters.input,



rule diagnoses_figures:
    input:
        rules.diagnoses_discovery_figures.input,
        rules.diagnoses_validation_figures.input,
        rules.diagnoses_comparison_figures.input,
        rules.diagnoses_inclusion_counts_figures.input,



rule diagnoses:
    input:
        rules.diagnoses_tables.input,
        rules.diagnoses_parameters.input,
        rules.diagnoses_figures.input,
        rules.diagnoses_outputs.input,
