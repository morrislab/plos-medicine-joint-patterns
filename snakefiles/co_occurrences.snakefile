"""
Calculates joint co-occurrences.
"""

ANALYSES = ['conditional', 'raw']

SITE_ORDER = 'data/site_order_lr.txt'
INPUT = 'inputs/co_occurrences/joints/{cohort}.csv'
DISCOVERY_INPUT = expand(INPUT, cohort='discovery')



# Link inputs.

rule co_occurrences_inputs_joints_pattern:
    output: INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule co_occurrences_inputs:
    input:
        DISCOVERY_INPUT,



# Calculate co-occurrences.

rule co_occurrences_co_occurrences_discovery:
    output: 'tables/co_occurrences/co_occurrences/discovery.feather'
    log: 'tables/co_occurrences/co_occurrences/discovery.log'
    benchmark: 'tables/co_occurrences/co_occurrences/discovery.txt'
    input: DISCOVERY_INPUT
    version: v('scripts/co_occurrences/get_co_occurrences.py')
    shell:
        'python scripts/co_occurrences/get_co_occurrences.py --original-input {input} --output {output}' + LOG



rule co_occurrences_co_occurrences:
    input:
        rules.co_occurrences_co_occurrences_discovery.output,



rule co_occurrences_conditional_fig_discovery:
    output: 'figures/co_occurrences/conditional/discovery.pdf'
    log: 'figures/co_occurrences/conditional/discovery.log'
    benchmark: 'figures/co_occurrences/conditional/discovery.txt'
    input:
        data=rules.co_occurrences_co_occurrences_discovery.output,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=6
    version: v('scripts/co_occurrences/plot_co_occurrence_matrices.R')
    shell:
        'Rscript scripts/co_occurrences/plot_co_occurrence_matrices.R --co-occurrence-input {input.data} --joint-order {input.site_order} --output {output} --figure-width {params.width} --figure-height {params.height} --show-labels --colour-scale --what conditional' + LOG



rule co_occurrences_conditional_fig:
    input:
        rules.co_occurrences_conditional_fig_discovery.output,



# Run Fisher's exact test to see which pairs of joints co-occur more often than
# expected.

rule co_occurrences_raw_stats_discovery:
    output: 'tables/co_occurrences/raw/stats/discovery.csv'
    log: 'tables/co_occurrences/raw/stats/discovery.log'
    benchmark: 'tables/co_occurrences/raw/stats/discovery.txt'
    input: DISCOVERY_INPUT
    threads: 96
    version: v('scripts/co_occurrences/get_raw_stats.R')
    shell:
        'Rscript scripts/co_occurrences/get_raw_stats.R --data-input {input} --output {output} --threads {threads}' + LOG



rule co_occurrences_raw_stats:
    input:
        rules.co_occurrences_raw_stats_discovery.output,



# Plot odds ratios for co-involvements.

rule co_occurrences_odds_ratios_fig_pattern:
    output: 'figures/co_occurrences/odds_ratios/{cohort}.pdf'
    log: 'figures/co_occurrences/odds_ratios/{cohort}.log'
    benchmark: 'figures/co_occurrences/odds_ratios/{cohort}.txt'
    input:
        data='tables/co_occurrences/fisher/stats/{cohort}.csv',
        site_order=SITE_ORDER,
    params:
        width=6,
        height=6,
    version: v('scripts/co_occurrences/plot_odds_ratios.R')
    shell:
        'Rscript scripts/co_occurrences/plot_odds_ratios.R --data-input {input.data} --site-order-input {input.site_order} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule co_occurrences_odds_ratios_fig:
    input:
        expand(rules.co_occurrences_odds_ratios_fig_pattern.output, cohort='discovery')



# Calculate conditional statistics.

rule co_occurrences_stats_conditional_base_discovery:
    output: 'tables/co_occurrences/stats/conditional/base/discovery.csv'
    log: 'tables/co_occurrences/stats/conditional/base/discovery.log'
    benchmark: 'tables/co_occurrences/stats/conditional/base/discovery.txt'
    input:
        data=DISCOVERY_INPUT,
        co_occurrences=rules.co_occurrences_co_occurrences_discovery.output,
    params:
        iterations=config.co_occurrences.conditional.iterations,
        seed=config.co_occurrences.conditional.seed,
    threads: 96
    version: v('scripts/co_occurrences/get_conditional_stats.py')
    shell:
        'python scripts/co_occurrences/get_conditional_stats.py --data-input {input.data} --co-occurrence-input {input.co_occurrences} --output {output} --iterations {params.iterations} --seed {params.seed} --threads {threads}' + LOG



rule co_occurrences_stats_conditional_base:
    input:
        rules.co_occurrences_stats_conditional_base_discovery.output,



# Adjust P-values for the conditional stats.

rule co_occurrences_stats_conditional_adjusted_discovery:
    output: 'tables/co_occurrence/discovery/stats/conditional/adjusted/discovery.csv'
    log: 'tables/co_occurrence/discovery/stats/conditional/adjusted/discovery.log'
    benchmark: 'tables/co_occurrence/discovery/conditional/adjusted/discovery.txt'
    input: rules.co_occurrences_stats_conditional_base_discovery.output
    version: v('scripts/co_occurrences/adjust_conditional_stats.R')
    shell:
        'Rscript scripts/co_occurrences/adjust_conditional_stats.R --input {input} --output {output}' + LOG



rule co_occurrences_stats_conditional_adjusted:
    input:
        rules.co_occurrences_stats_conditional_adjusted_discovery.output,



# Other includes.

include: 'co_occurrences/conditional.snakefile'
include: 'co_occurrences/fisher.snakefile'
include: 'co_occurrences/z.snakefile'



# Targets.

rule co_occurrences_tables:
    input:
        rules.co_occurrences_co_occurrences.input,
        rules.co_occurrences_raw_stats.input,
        rules.co_occurrences_stats_conditional_base.input,
        rules.co_occurrences_stats_conditional_adjusted.input,
        rules.co_occurrences_conditional_tables.input,
        rules.co_occurrences_fisher_tables.input,
        rules.co_occurrences_z_tables.input



rule co_occurrences_parameters:
    input:
        rules.co_occurrences_conditional_parameters.input,
        rules.co_occurrences_fisher_parameters.input,
        rules.co_occurrences_z_parameters.input,



rule co_occurrences_figures:
    input:
        rules.co_occurrences_conditional_fig.input,
        rules.co_occurrences_odds_ratios_fig.input,
        rules.co_occurrences_conditional_figures.input,
        rules.co_occurrences_fisher_figures.input,
        rules.co_occurrences_z_figures.input



rule co_occurrences:
    input:
        rules.co_occurrences_inputs.input,
        rules.co_occurrences_tables.input,
        rules.co_occurrences_parameters.input,
        rules.co_occurrences_figures.input
