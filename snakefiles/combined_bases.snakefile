"""
Combines bases from multiple levels of NMF together for visualization purposes.
"""

LEVELS = config.combined_bases.levels
TARGET_LEVELS = LEVELS[1:]

SITE_ORDER = 'data/site_order.txt'



# Link inputs.

rule combined_bases_inputs_basis_pattern:
    output: 'inputs/combined_bases/bases/{cohort}/{level}.csv'
    input: 'outputs/nmf/{cohort}/{level}/model/basis.csv'
    shell: LN



rule combined_bases_inputs_scaling_parameters_pattern:
    output: 'inputs/combined_bases/scaling_parameters/{cohort}/{level}.csv'
    input: 'outputs/nmf/{cohort}/{level}/scaled/parameters.csv'
    shell: LN



rule combined_bases_inputs:
    input:
        expand(rules.combined_bases_inputs_basis_pattern.output, cohort=COHORTS, level=LEVELS),
        expand(rules.combined_bases_inputs_scaling_parameters_pattern.output, cohort=COHORTS, level=TARGET_LEVELS),



# Generate the combined bases.

rule combined_bases_basis_l2_pattern:
    output: 'tables/combined_bases/{cohort}/l2.csv'
    log: 'tables/combined_bases/{cohort}/l2.log'
    benchmark: 'tables/combined_bases/{cohort}/l2.txt'
    input:
        bases=expand('inputs/combined_bases/bases/{{cohort}}/{level}.csv', level=['l1', 'l2']),
        scaling_params='inputs/combined_bases/scaling_parameters/{cohort}/l2.csv',
    version: v('scripts/nmf/combine_bases.py')
    shell:
        'python scripts/nmf/combine_bases.py --basis-inputs {input.bases} --scaling-parameter-inputs {input.scaling_params} --output {output}' + LOG



rule combined_bases_basis_l2:
    input:
        expand(rules.combined_bases_basis_l2_pattern.output, cohort=COHORTS),



rule combined_bases_basis:
    input:
        rules.combined_bases_basis_l2.input,



# Plot the combined bases.

rule combined_bases_fig_pattern:
    output: 'figures/combined_bases/{cohort}/{level}.pdf'
    log: 'figures/combined_bases/{cohort}/{level}.log'
    benchmark: 'figures/combined_bases/{cohort}/{level}.txt'
    input:
        basis='tables/combined_bases/{cohort}/{level}.csv',
        site_order=SITE_ORDER,
    params:
        width=3,
        height=8,
        option=VIRIDIS_PALETTE,
    version: v('scripts/nmf/plot_basis_asis.R')
    shell:
        'Rscript scripts/nmf/plot_basis_asis.R --input {input.basis} --site-order {input.site_order} --output {output} --width {params.width} --height {params.height} --colour-scale --max-scaling --option {params.option}' + LOG



rule combined_bases_fig:
    input:
        expand(rules.combined_bases_fig_pattern.output, cohort=COHORTS, level=TARGET_LEVELS),



# Link outputs.

rule combined_bases_outputs_pattern:
    output: 'outputs/combined_bases/{cohort}/{level}.csv'
    input: 'tables/combined_bases/{cohort}/{level}.csv'
    shell: LN



rule combined_bases_outputs:
    input:
        expand(rules.combined_bases_outputs_pattern.output, cohort=COHORTS, level=TARGET_LEVELS),



# Targets.

rule combined_bases_tables:
    input:
        rules.combined_bases_basis.input,



rule combined_bases_parameters:
    input:



rule combined_bases_figures:
    input:
        rules.combined_bases_fig.input,



rule combined_bases:
    input:
        rules.combined_bases_inputs.input,
        rules.combined_bases_tables.input,
        rules.combined_bases_parameters.input,
        rules.combined_bases_figures.input,
        rules.combined_bases_outputs.input,
