"""
Generates base information about how often each site is involved in the entire cohort.
"""

INPUT = 'inputs/site_probabilities/joints/{cohort}.csv'



# Link inputs.

rule site_probabilities_inputs_pattern:
    output: INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule site_probabilities_inputs:
    input:
        expand(INPUT, cohort=COHORTS),



# Generate the base figure.

rule site_probabilities_fig_pattern:
    output: 'figures/site_probabilities/{cohort}.pdf'
    log: 'figures/site_probabilities/{cohort}.log'
    benchmark: 'figures/site_probabilities/{cohort}.txt'
    input: INPUT
    params:
        option=VIRIDIS_PALETTE,
    version: v('scripts/site_probabilities/plot_probabilities.R')
    shell:
        'Rscript scripts/site_probabilities/plot_probabilities.R --input {input} --output {output} --option {params.option}' + LOG



rule site_probabilities_fig:
    input:
        expand(rules.site_probabilities_fig_pattern.output, cohort='discovery'),



# Targets.

rule site_probabilities_tables:
    input:



rule site_probabilities_parameters:
    input:



rule site_probabilities_figures:
    input:
        rules.site_probabilities_fig.input,



rule site_probabilities:
    input:
        rules.site_probabilities_inputs.input,
        rules.site_probabilities_tables.input,
        rules.site_probabilities_parameters.input,
        rules.site_probabilities_figures.input,
