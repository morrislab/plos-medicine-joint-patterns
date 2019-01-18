"""
Counts and plots the number of patients with given localizations.
"""

INPUT = 'inputs/localizations/counts/data/{cohort}/{level}.csv'



# Link the data.

rule localizations_counts_inputs_pattern:
    output: INPUT
    input: 'tables/localizations/assignments/{cohort}/{level}.csv'
    shell: LN



rule localizations_counts_inputs:
    input:
        expand(INPUT, cohort='discovery', level=LEVELS),



# Generate counts.

rule localizations_counts_counts_pattern:
    output: 'tables/localizations/counts/counts/{cohort}/{level}.csv'
    log: 'tables/localizations/counts/counts/{cohort}/{level}.log'
    benchmark: 'tables/localizations/counts/counts/{cohort}/{level}.txt'
    input: INPUT
    version: v('scripts/localizations/counts/get_counts.py')
    shell:
        'python scripts/localizations/counts/get_counts.py --input {input} --output {output}' + LOG



rule localizations_counts_counts:
    input:
        expand(rules.localizations_counts_counts_pattern.output, cohort='discovery', level=LEVELS),



# Plot counts.

rule localizations_counts_fig_pattern:
    output: 'figures/localizations/counts/{cohort}/{level}.pdf'
    log: 'figures/localizations/counts/{cohort}/{level}.log'
    benchmark: 'figures/localizations/counts/{cohort}/{level}.txt'
    input: rules.localizations_counts_counts_pattern.output
    params:
        width=6,
        height=3,
    version: v('scripts/localizations/counts/plot_counts.R')
    shell:
        'Rscript scripts/localizations/counts/plot_counts.R --input {input} --output {output} --width {params.width} --height {params.height}' + LOG



rule localizations_counts_fig:
    input:
        expand(rules.localizations_counts_fig_pattern.output, cohort='discovery', level=LEVELS),



# Targets.

rule localizations_counts_tables:
    input:
        rules.localizations_counts_counts.input,



rule localizations_counts_parameters:
    input:



rule localizations_counts_figures:
    input:
        rules.localizations_counts_fig.input,



rule localizations_counts:
    input:
        rules.localizations_counts_inputs.input,
        rules.localizations_counts_tables.input,
        rules.localizations_counts_parameters.input,
        rules.localizations_counts_figures.input,
