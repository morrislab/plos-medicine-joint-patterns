"""
Fisher's exact tests to compare the following quantities:

- P_1 = P(same side conditional joint | joint)
- P_2 = P(opposite side conditional joint | joint)

...using contigency tables:

+-----------------+----------------+
| P_1 (successes) | P_1 (failures) |
+-----------------+----------------+
| P_2 (successes) | P_2 (failures) |
+-----------------+----------------+
"""

JOINTS_INPUT = 'inputs/co_occurrences/fisher/joints/{cohort}.csv'
CO_OCCURRENCES_INPUT = 'inputs/co_occurrences/fisher/co_occurrences/{cohort}.feather'

SITE_ORDER = 'data/site_order_deltas.txt'



# Link inputs.

rule co_occurrences_fisher_inputs_joints_pattern:
    output: JOINTS_INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule co_occurrences_fisher_inputs_joints:
    input:
        expand(JOINTS_INPUT, cohort='discovery'),



rule co_occurrences_fisher_inputs_co_occurrences_pattern:
    output: CO_OCCURRENCES_INPUT
    input: 'tables/co_occurrences/co_occurrences/{cohort}.feather'
    shell: LN



rule co_occurrences_fisher_inputs_co_occurrences:
    input:
        expand(CO_OCCURRENCES_INPUT, cohort='discovery'),



rule co_occurrences_fisher_inputs:
    input:
        rules.co_occurrences_fisher_inputs_joints.input,
        rules.co_occurrences_fisher_inputs_co_occurrences.input,



# Conduct statistics.

rule co_occurrences_fisher_stats_pattern:
    output: 'tables/co_occurrences/fisher/stats/{cohort}.csv'
    log: 'tables/co_occurrences/fisher/stats/{cohort}.log'
    benchmark: 'tables/co_occurrences/fisher/stats/{cohort}.txt'
    input: JOINTS_INPUT
    version: v('scripts/co_occurrences/fisher/get_stats.R')
    shell:
        'Rscript scripts/co_occurrences/fisher/get_stats.R --input {input.data} --output {output}' + LOG



rule co_occurrences_fisher_stats:
    input:
        expand(rules.co_occurrences_fisher_stats_pattern.output, cohort='discovery'),



# Generate a figure of filtered co-involvement frequencies.

rule co_occurrences_fisher_ratios_pattern:
    output: 'tables/co_occurrences/fisher/ratios/{cohort}.csv'
    log: 'tables/co_occurrences/fisher/ratios/{cohort}.log'
    benchmark: 'tables/co_occurrences/fisher/ratios/{cohort}.txt'
    input: CO_OCCURRENCES_INPUT
    version: v('scripts/co_occurrences/fisher/get_ratios.py')
    shell:
        'python scripts/co_occurrences/fisher/get_ratios.py --input {input} --output {output}' + LOG



rule co_occurrences_fisher_ratios:
    input:
        expand(rules.co_occurrences_fisher_ratios_pattern.output, cohort='discovery')



rule co_occurrences_fisher_ratios_fig_raw_pattern:
    output: 'figures/co_occurrences/fisher/ratios/raw/{cohort}.pdf'
    log: 'figures/co_occurrences/fisher/ratios/raw/{cohort}.log'
    benchmark: 'figures/co_occurrences/fisher/ratios/raw/{cohort}.txt'
    input:
        ratios=rules.co_occurrences_fisher_ratios_pattern.output,
        stats=rules.co_occurrences_fisher_stats_pattern.output,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=8,
    version: v('scripts/co_occurrences/fisher/plot_ratios.R')
    shell:
        'Rscript scripts/co_occurrences/fisher/plot_ratios.R --ratio-input {input.ratios} --stats-input {input.stats} --site-order-input {input.site_order} --output {output} --figure-width {params.width} --figure-height {params.height} --plot-all' + LOG



rule co_occurrences_fisher_ratios_fig_filtered_pattern:
    output: 'figures/co_occurrences/fisher/ratios/filtered/{cohort}.pdf'
    log: 'figures/co_occurrences/fisher/ratios/filtered/{cohort}.log'
    benchmark: 'figures/co_occurrences/fisher/ratios/filtered/{cohort}.txt'
    input:
        ratios=rules.co_occurrences_fisher_ratios_pattern.output,
        stats=rules.co_occurrences_fisher_stats_pattern.output,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=8,
    version: v('scripts/co_occurrences/fisher/plot_ratios.R')
    shell:
        'Rscript scripts/co_occurrences/fisher/plot_ratios.R --ratio-input {input.ratios} --stats-input {input.stats} --site-order-input {input.site_order} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



# TODO Fix this

rule co_occurrences_fisher_ratios_fig:
    input:
        # expand(rules.co_occurrences_fisher_ratios_fig_raw_pattern.output, cohort='discovery'),
        # expand(rules.co_occurrences_fisher_ratios_fig_filtered_pattern.output, cohort='discovery'),




# Targets.

rule co_occurrences_fisher_tables:
    input:
        rules.co_occurrences_fisher_stats.input,
        rules.co_occurrences_fisher_ratios.input



rule co_occurrences_fisher_parameters:
    input:



rule co_occurrences_fisher_figures:
    input:
        rules.co_occurrences_fisher_ratios_fig.input



rule co_occurrences_fisher:
    input:
        rules.co_occurrences_fisher_inputs.input,
        rules.co_occurrences_fisher_tables.input,
        rules.co_occurrences_fisher_parameters.input,
        rules.co_occurrences_fisher_figures.input
