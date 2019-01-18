"""
Compares distributions in categories among patients included and excluded.
"""

DISCOVERY_INCLUDED_INPUT = 'inputs/diagnoses/inclusion_counts/discovery/included.csv'
DISCOVERY_ALL_INPUT = 'inputs/diagnoses/inclusion_counts/discovery/all.csv'

# Link inputs.

rule diagnoses_inclusion_counts_inputs_included:
    output: DISCOVERY_INCLUDED_INPUT
    input: 'outputs/diagnoses/discovery.csv'
    shell: LN



rule diagnoses_inclusion_counts_inputs_all:
    output: DISCOVERY_ALL_INPUT
    input: 'outputs/diagnoses/discovery_all.csv'
    shell: LN



rule diagnoses_inclusion_counts_inputs:
    input:
        DISCOVERY_INCLUDED_INPUT,
        DISCOVERY_ALL_INPUT,



# Generate the raw counts.

rule diagnoses_inclusion_counts_counts_discovery:
    output: 'tables/diagnoses/inclusion_counts/counts/discovery.csv'
    log: 'tables/diagnoses/inclusion_counts/counts/discovery.log'
    benchmark: 'tables/diagnoses/inclusion_counts/counts/discovery.txt'
    input:
        all=DISCOVERY_ALL_INPUT,
        included=DISCOVERY_INCLUDED_INPUT,
    version: v('scripts/diagnoses/inclusion_counts/get_counts.py')
    shell:
        'python scripts/diagnoses/inclusion_counts/get_counts.py --all-input {input.all} --included-input {input.included} --output {output}' + LOG



rule diagnoses_inclusion_counts_counts:
    input:
        expand('tables/diagnoses/inclusion_counts/counts/{cohort}.csv', cohort='discovery'),



# Plot the frequencies.

rule diagnoses_inclusion_counts_fig_pattern:
    output: 'figures/diagnoses/inclusion_counts/{cohort}.pdf'
    log: 'figures/diagnoses/inclusion_counts/{cohort}.log'
    benchmark: 'figures/diagnoses/inclusion_counts/{cohort}.txt'
    input: 'tables/diagnoses/inclusion_counts/counts/{cohort}.csv'
    params:
        width=6,
        height=3,
    version: v('scripts/diagnoses/inclusion_counts/plot_frequencies.R')
    shell:
        'Rscript scripts/diagnoses/inclusion_counts/plot_frequencies.R --input {input} --output {output} --width {params.width} --height {params.height}' + LOG



rule diagnoses_inclusion_counts_fig:
    input:
        expand(rules.diagnoses_inclusion_counts_fig_pattern.output, cohort='discovery'),



# Conduct statistics.

rule diagnoses_inclusion_counts_stats_pattern:
    output: 'tables/diagnoses/inclusion_counts/stats/{cohort}.xlsx'
    log: 'tables/diagnoses/inclusion_counts/stats/{cohort}.log'
    benchmark: 'tables/diagnoses/inclusion_counts/stats/{cohort}.txt'
    input: 'tables/diagnoses/inclusion_counts/counts/{cohort}.csv'
    version: v('scripts/diagnoses/inclusion_counts/do_stats.R')
    shell:
        'Rscript scripts/diagnoses/inclusion_counts/do_stats.R --input {input} --output {output}' + LOG



rule diagnoses_inclusion_counts_stats:
    input:
        expand(rules.diagnoses_inclusion_counts_stats_pattern.output, cohort='discovery'),



# Link outputs.

rule diagnoses_inclusion_counts_outputs:
    input:



# Targets.

rule diagnoses_inclusion_counts_tables:
    input:
        rules.diagnoses_inclusion_counts_counts.input,
        rules.diagnoses_inclusion_counts_stats.input,



rule diagnoses_inclusion_counts_parameters:
    input:



rule diagnoses_inclusion_counts_figures:
    input:
        rules.diagnoses_inclusion_counts_fig.input,



rule diagnoses_inclusion_counts:
    input:
        rules.diagnoses_inclusion_counts_tables.input,
        rules.diagnoses_inclusion_counts_parameters.input,
        rules.diagnoses_inclusion_counts_figures.input,