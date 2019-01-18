"""
Site counts.
"""

DATA_INPUT = 'inputs/site_counts/data/{cohort}.csv'
CLUSTER_INPUT = 'inputs/site_counts/clusters/{cohort}.csv'

# Link inputs.

rule site_counts_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule site_counts_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/{cohort}.csv'
    shell: LN



rule site_counts_inputs:
    input:
        expand(DATA_INPUT, cohort=COHORTS),
        expand(CLUSTER_INPUT, cohort=COHORTS),



# Site counts for the entire cohort.

rule site_counts_counts_pattern:
    output: 'tables/site_counts/counts/{cohort}.csv'
    log: 'tables/site_counts/counts/{cohort}.log'
    benchmark: 'tables/site_counts/counts/{cohort}.txt'
    input: DATA_INPUT
    version: v('scripts/site_counts/count_sites.py')
    shell:
        'python scripts/site_counts/count_sites.py --input {input} --output {output}' + LOG



rule site_counts_counts:
    input:
        expand(rules.site_counts_counts_pattern.output, cohort=COHORTS),



# Plot site counts for individual clusters.

rule site_counts_clusters_fig_pattern:
    output: 'figures/site_counts/clusters/{cohort}.pdf'
    log: 'figures/site_counts/clusters/{cohort}.log'
    benchmark: 'figures/site_counts/clusters/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
    params:
        width=3,
        height=3,
        boundary=4.5,
    version: v('scripts/site_counts/plot_site_counts.R')
    shell:
        'Rscript scripts/site_counts/plot_site_counts.R --data-input {input.data} --cluster-input {input.clusters} --output {output} --figure-width {params.width} --figure-height {params.height} --boundary {params.boundary}' + LOG



rule site_counts_clusters_fig:
    input:
        expand(rules.site_counts_clusters_fig_pattern.output, cohort=COHORTS),



# Plot of site count distributions.

rule site_counts_distribution_fig_pattern:
    output: 'figures/site_counts/distribution/{cohort}.pdf'
    log: 'figures/site_counts/distribution/{cohort}.log'
    benchmark: 'figures/site_counts/distribution/{cohort}.txt'
    input: rules.site_counts_counts_pattern.output
    params:
        width=9,
        height=3.75,
    version: v('scripts/site_counts/plot_global_histogram.R')
    shell:
        'Rscript scripts/site_counts/plot_global_histogram.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule site_counts_distribution_fig:
    input:
        expand(rules.site_counts_distribution_fig_pattern.output, cohort=COHORTS),



# Stats.

rule site_counts_stats_pattern:
    output: 'tables/site_counts/stats/{cohort}.csv'
    log: 'tables/site_counts/stats/{cohort}.log'
    benchmark: 'tables/site_counts/stats/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
    params:
        tau=[0.5, 0.75],
    version: v('scripts/site_counts/do_stats.R')
    shell:
        'Rscript scripts/site_counts/do_stats.R --data-input {input.data} --cluster-input {input.clusters} --output {output} --tau {params.tau}' + LOG



rule site_counts_stats:
    input:
        expand(rules.site_counts_stats_pattern.output, cohort=COHORTS),



# Overlapping histograms.

rule site_counts_distributions_combined_fig:
    output: 'figures/site_counts/distributions/combined.pdf'
    log: 'figures/site_counts/distributions/combined.log'
    benchmark: 'figures/site_counts/distributions/combined.txt'
    input: expand(rules.site_counts_counts_pattern.output, cohort=COHORTS),
    params:
        labels=['Discovery', 'Validation'],
        width=9,
        height=6,
    version: v('scripts/site_counts/plot_distributions.R')
    shell:
        'Rscript scripts/site_counts/plot_distributions.R --input {input} --output {output} --labels {params.labels:q} --figure-width {params.width} --figure-height {params.height}' + LOG



# Link outputs.

rule site_counts_outputs_pattern:
    output: 'outputs/site_counts/{cohort}.csv'
    input: rules.site_counts_counts_pattern.output
    shell: LN



rule site_counts_outputs:
    input:
        expand(rules.site_counts_outputs_pattern.output, cohort=COHORTS),



# Targets.

rule site_counts_tables:
    input:
        rules.site_counts_counts.input,
        rules.site_counts_stats.input,



rule site_counts_parameters:
    input:



rule site_counts_figures:
    input:
        rules.site_counts_distribution_fig.input,
        rules.site_counts_clusters_fig.input,
        rules.site_counts_distributions_combined_fig.output,



rule site_counts:
    input:
        rules.site_counts_inputs.input,
        rules.site_counts_tables.input,
        rules.site_counts_parameters.input,
        rules.site_counts_figures.input,
        rules.site_counts_outputs.input,
