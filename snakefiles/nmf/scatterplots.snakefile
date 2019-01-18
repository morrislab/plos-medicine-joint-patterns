"""
Plots scatterplots of scores on NMF factors.
"""

INPUT = 'inputs/nmf/scatterplots/{cohort}/{level}/scores.csv'
LEVELS = ['l1', 'l2']



# Link inputs.

rule nmf_scatterplots_inputs_pattern:
    output: INPUT
    input: 'outputs/nmf/{cohort}/{level}/scores.csv'
    shell: LN



rule nmf_scatterplots_inputs:
    input:
        expand(rules.nmf_scatterplots_inputs_pattern.output, cohort='discovery', level=LEVELS),



# Generate a scatterplot.

rule nmf_scatterplots_fig_pattern:
    output: 'figures/nmf/scatterplots/{cohort}/{level}.pdf'
    log: 'figures/nmf/scatterplots/{cohort}/{level}.log'
    benchmark: 'figures/nmf/scatterplots/{cohort}/{level}.txt'
    input: INPUT
    params:
        width=5,
        height=5,
    version: v('scripts/nmf/plot_scatterplots.R')
    shell:
        'Rscript scripts/nmf/plot_scatterplots.R --input {input} --output {output} --width {params.width} --height {params.height}' + LOG



rule nmf_scatterplots_fig:
    input:
        expand(rules.nmf_scatterplots_fig_pattern.output, cohort='discovery', level=LEVELS),



# Targets.

rule nmf_scatterplots_tables:
    input:



rule nmf_scatterplots_parameters:
    input:



rule nmf_scatterplots_figures:
    input:
        rules.nmf_scatterplots_fig.input,



rule nmf_scatterplots:
    input:
        rules.nmf_scatterplots_inputs.input,
        rules.nmf_scatterplots_tables.input,
        rules.nmf_scatterplots_parameters.input,
        rules.nmf_scatterplots_figures.input,
