"""
Analyzes joint co-occurrences by, for each joint type, counting the number of
patients with same-side pairings and the number with opposite-side pairings.

We first calculate a quality `P = (n_{same side} + c) / (n_{same side} +
n_opposite side + 2c)`, where `c` is a constant to avoid division by zero. We
note that a patient can be counted twice. For example, a patient can have both a
same-side hip and an opposite-side hip involved.

For the resulting matrix we display, we can calculate Z-scores by first
calculating `sigma = sqrt(p * (1 - p) / n)`, then `z = (p - 0.5) / sigma`.
"""

Z_C = config.co_occurrences.z.c

INPUT = 'inputs/co_occurrences/z/joints/{cohort}.csv'
SITE_ORDER = 'data/site_order_deltas.txt'



# Link inputs.

rule co_occurrences_z_inputs_joints_pattern:
    output: INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule co_occcurrences_z_inputs_joints:
    input:
        expand(INPUT, cohort='discovery'),



rule co_occurrences_z_inputs:
    input:
        rules.co_occcurrences_z_inputs_joints.input,



# Calculate statistics.

rule co_occurrences_z_statistics_pattern:
    output: 'tables/co_occurrences/z/statistics/{cohort}/c{c}.feather'
    log: 'tables/co_occurrences/z/statistics/{cohort}/c{c}.log'
    benchmark: 'tables/co_occurrences/z/statistics/{cohort}/c{c}.txt'
    input: INPUT
    version: v('scripts/co_occurrences/z/get_stats.py')
    shell:
        'python scripts/co_occurrences/z/get_stats.py --input {input} --output {output} --c {wildcards.c}' + LOG



rule co_occurrences_z_statistics:
    input:
        expand(rules.co_occurrences_z_statistics_pattern.output, cohort='discovery', c=Z_C),



# Conduct chi-squared tests to determine which site types display significant
# same-side or opposite-side skewing.

rule co_occurrences_z_chisq_pattern:
    output: 'tables/co_occurrences/z/chisq/{cohort}/c{c}.csv'
    log: 'tables/co_occurrences/z/chisq/{cohort}/c{c}.log'
    benchmark: 'tables/co_occurrences/z/chisq/{cohort}/c{c}.txt'
    input: rules.co_occurrences_z_statistics_pattern.output
    version: v('scripts/co_occurrences/z/do_chisq.R')
    shell:
        'Rscript scripts/co_occurrences/z/do_chisq.R --input {input} --output {output}' + LOG



rule co_occurrences_z_chisq:
    input:
        expand(rules.co_occurrences_z_chisq_pattern.output, cohort='discovery', c=Z_C)



# Plot Z-scores.

rule co_occurrences_z_fig_pattern:
    output: 'figures/co_occurrences/z/{cohort}/c{c}.pdf'
    log: 'figures/co_occurrences/z/{cohort}/c{c}.log'
    benchmark: 'figures/co_occurrences/z/{cohort}/c{c}.txt'
    input:
        data=rules.co_occurrences_z_statistics_pattern.output,
        statistics=rules.co_occurrences_z_chisq_pattern.output,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=6,
        percentile_threshold=5e-15,
    version: v('scripts/co_occurrences/z/plot_matrix.R')
    shell:
        'Rscript scripts/co_occurrences/z/plot_matrix.R --data-input {input.data} --statistics-input {input.statistics} --site-order-input {input.site_order} --output {output} --width {params.width} --height {params.height} --percentile-threshold {params.percentile_threshold}' + LOG



rule co_occurrences_z_fig:
    input:
        expand(rules.co_occurrences_z_fig_pattern.output, cohort='discovery', c=Z_C)



# Targets.

rule co_occurrences_z_tables:
    input:
        rules.co_occurrences_z_statistics.input,
        rules.co_occurrences_z_chisq.input,



rule co_occurrences_z_parameters:
    input:



rule co_occurrences_z_figures:
    input:
        rules.co_occurrences_z_fig.input,



rule co_occurrences_z:
    input:
        rules.co_occurrences_z_inputs.input,
        rules.co_occurrences_z_tables.input,
        rules.co_occurrences_z_parameters.input,
        rules.co_occurrences_z_figures.input,
