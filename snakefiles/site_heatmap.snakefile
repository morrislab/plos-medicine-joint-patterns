"""
Generates site heat maps.
"""

DATA_INPUT = 'inputs/site_heatmap/data/{cohort}.csv'
KEY_SITE_INPUT = 'inputs/site_heatmap/key_sites/{cohort}/{level}.csv'
CLUSTER_INPUT = 'inputs/site_heatmap/clusters/{cohort}/{level}.csv'
SITE_ORDER = 'data/site_order_site_heatmap.txt'

LEVELS = config.site_heatmap.levels



# Link inputs.

rule site_heatmap_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule site_heatmap_inputs_key_sites_pattern:
    output: KEY_SITE_INPUT
    input: 'outputs/representative_sites/{cohort}/{level}.csv'
    shell: LN



rule site_heatmap_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/levels/{cohort}/{level}.csv'
    shell: LN



rule site_heatmap_inputs:
    input:
        expand(rules.site_heatmap_inputs_data_pattern.output, cohort='discovery'),
        expand(rules.site_heatmap_inputs_key_sites_pattern.output, cohort='discovery', level=LEVELS),
        expand(rules.site_heatmap_inputs_clusters_pattern.output, cohort='discovery', level=LEVELS),



# Generate the heat map.

rule site_heatmap_fig_pattern:
    output: 'figures/site_heatmap/{cohort}/{level}.pdf'
    log: 'figures/site_heatmap/{cohort}/{level}.log'
    benchmark: 'figures/site_heatmap/{cohort}/{level}.txt'
    input:
        sites=DATA_INPUT,
        site_order=SITE_ORDER,
        representative_sites=KEY_SITE_INPUT,
        clusters=CLUSTER_INPUT,
    params:
        width=6,
        height=6,
    version: v('scripts/site_heatmap/plot_site_heatmap.R')
    shell:
        'Rscript scripts/site_heatmap/plot_site_heatmap.R --data-input {input.sites} --cluster-input {input.clusters} --site-order-input {input.site_order} --representative-site-input {input.representative_sites} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule site_heatmap_fig:
    input:
        expand(rules.site_heatmap_fig_pattern.output, cohort='discovery', level=LEVELS),




# Targets.

rule site_heatmap_tables:
    input:



rule site_heatmap_parameters:
    input:



rule site_heatmap_figures:
    input:
        rules.site_heatmap_fig.input,



rule site_heatmap:
    input:
        rules.site_heatmap_inputs.input,
        rules.site_heatmap_tables.input,
        rules.site_heatmap_parameters.input,
        rules.site_heatmap_figures.input,
