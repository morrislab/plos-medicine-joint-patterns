"""
Generates heat maps:
1.  Of transition probabilities between pairs of visits
2.  Displaying the probability of transitioning from a cluster to another at any time
    point.
3.  Of transition probabilities dependent on localization.
"""


ANALYSES = ['base', 'localizations']
PARAMS = config.cluster_trajectories.discovery

BATCHES = [k + 1 for k in range(PARAMS.permutation_test.batches)]
LOCALIZATIONS = ['localized', 'partial', 'extended']

CLUSTERS = 'tables/cluster_trajectories/discovery/clusters/{analysis}.csv'



# Data, including split data for plotting.

rule cluster_trajectories_discovery_heatmap_data_base_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/data/base/{analysis}.csv'
    log: 'tables/cluster_trajectories/discovery/heatmap/data/base/{analysis}.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/data/base/{analysis}.txt'
    input: CLUSTERS
    version: v('scripts/group_trajectories/get_heatmap_data_any.py')
    shell:
        'python scripts/group_trajectories/get_heatmap_data_any.py --input {input} --output {output}' + LOG



rule cluster_trajectories_discovery_heatmap_data_base:
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_data_base_pattern.output, analysis=ANALYSES),



rule cluster_trajectories_discovery_heatmap_data_localized_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/data/localized/{localization}.csv'
    input: expand(rules.cluster_trajectories_discovery_heatmap_data_base_pattern.output, analysis='localizations')
    shell:
        "head -n 1 {input} > {output} && awk '/_{wildcards.localization}/' {input} >> {output}"



rule cluster_trajectories_discovery_heatmap_data_localized:
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_data_localized_pattern.output, localization=LOCALIZATIONS),



rule cluster_trajectories_discovery_heatmap_data:
    input:
        rules.cluster_trajectories_discovery_heatmap_data_base.input,
        rules.cluster_trajectories_discovery_heatmap_data_localized.input,



# Generate seeds for the permutation test.

rule cluster_trajectories_discovery_heatmap_stats_seeds:
    output:
        expand('tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/{batch}.txt', batch=BATCHES),
        flag=touch('tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/seeds.done')
    log: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/seeds.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/seeds.txt'
    params:
        batches=PARAMS.permutation_test.batches,
        permutations_per_batch=PARAMS.permutation_test.permutations_per_batch,
        seed=PARAMS.permutation_test.seed,
        prefix='tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/'
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.prefix} --jobs {params.batches} --iterations-per-job {params.permutations_per_batch} --seed {params.seed}' + LOG



# Generate permutation test samples.

rule cluster_trajectories_discovery_heatmap_stats_samples_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{analysis}/samples/{batch}.feather'
    log: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{analysis}/samples/{batch}.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{analysis}/samples/{batch}.txt'
    input:
        rules.cluster_trajectories_discovery_heatmap_stats_seeds.output.flag,
        data=CLUSTERS,
        seedlist='tables/cluster_trajectories/discovery/heatmap/permutation_test/seeds/{batch}.txt',
    version: v('scripts/group_trajectories/get_permutation_samples_any.py')
    shell:
        'python scripts/group_trajectories/get_permutation_samples_any.py --input {input.data} --seedlist {input.seedlist} --output {output}' + LOG



rule cluster_trajectories_discovery_heatmap_stats_samples:
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_stats_samples_pattern.output, analysis=ANALYSES, batch=BATCHES)



# Concatenate the samples.

rule cluster_trajectories_discovery_heatmap_stats_concatenated_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/concatenated/{analysis}.feather'
    log: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/concatenated/{analysis}.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/concatenated/{analysis}.txt'
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_stats_samples_pattern.output, batch=BATCHES, analysis='{analysis}')
    version: v('scripts/group_trajectories/concatenate_permutation_samples_any.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/group_trajectories/concatenate_permutation_samples_any.py --output {output} {inputs}' + LOG)



rule cluster_trajectories_discovery_heatmap_stats_concatenated:
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_stats_concatenated_pattern.output, analysis=ANALYSES),



# Generate statistics.

rule cluster_trajectories_discovery_heatmap_stats_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/p_values/{analysis}.csv'
    log: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/p_values/{analysis}.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/p_values/{analysis}.txt'
    input:
        probabilities=rules.cluster_trajectories_discovery_heatmap_data_base_pattern.output,
        concatenated=rules.cluster_trajectories_discovery_heatmap_stats_concatenated_pattern.output
    version: v('scripts/group_trajectories/get_permutation_p_values.py')
    shell:
        'python scripts/group_trajectories/get_permutation_p_values.py --probability-input {input.probabilities} --sample-input {input.concatenated} --output {output}' + LOG



rule cluster_trajectories_discovery_heatmap_stats:
    input:
        expand(rules.cluster_trajectories_discovery_heatmap_stats_pattern.output, analysis=ANALYSES),



# Generate the figures.

rule cluster_trajectories_discovery_heatmap_fig_base:
    output: 'figures/cluster_trajectories/discovery/heatmap/base.pdf'
    log: 'figures/cluster_trajectories/discovery/heatmap/base.log'
    benchmark: 'figures/cluster_trajectories/discovery/heatmap/base.txt'
    input:
        data=expand(rules.cluster_trajectories_discovery_heatmap_data_base_pattern.output, analysis='base'),
        stats=expand(rules.cluster_trajectories_discovery_heatmap_stats_pattern.output, analysis='base'),
    params:
        width=6,
        height=3,
    version: v('scripts/group_trajectories/plot_heatmap.R')
    shell:
        'Rscript scripts/group_trajectories/plot_heatmap.R --input {input.data} --stats-input {input.stats} --output {output} --width {params.width} --height {params.height} --colour-scale' + LOG



rule cluster_trajectories_discovery_heatmap_fig_localized_pattern:
    output: 'figures/cluster_trajectories/discovery/heatmap/{analysis}/{localization}.pdf'
    log: 'figures/cluster_trajectories/discovery/heatmap/{analysis}/{localization}.log'
    benchmark: 'figures/cluster_trajectories/discovery/heatmap/{analysis}/{localization}.txt'
    input:
        data=lambda wildcards: expand(rules.cluster_trajectories_discovery_heatmap_data_localized_pattern.output, localization=wildcards.localization),
        stats=rules.cluster_trajectories_discovery_heatmap_stats_pattern.output,
    params:
        width=6,
        height=2.5,
        option='B',
    version: v('scripts/group_trajectories/plot_heatmap.R')
    shell:
        'Rscript scripts/group_trajectories/plot_heatmap.R --input {input.data} --stats-input {input.stats} --output {output} --width {params.width} --height {params.height} --colour-scale --option {params.option}' + LOG



rule cluster_trajectories_discovery_heatmap_figs:
    input:
        rules.cluster_trajectories_discovery_heatmap_fig_base.output,
        expand(rules.cluster_trajectories_discovery_heatmap_fig_localized_pattern.output, analysis='localizations', localization=LOCALIZATIONS),



# Targets.

rule cluster_trajectories_discovery_heatmap_tables:
    input:
        rules.cluster_trajectories_discovery_heatmap_data.input,
        rules.cluster_trajectories_discovery_heatmap_stats_seeds.output,
        rules.cluster_trajectories_discovery_heatmap_stats_samples.input,
        rules.cluster_trajectories_discovery_heatmap_stats_concatenated.input,
        rules.cluster_trajectories_discovery_heatmap_stats.input,



rule cluster_trajectories_discovery_heatmap_parameters:
    input:



rule cluster_trajectories_discovery_heatmap_figures:
    input:
        rules.cluster_trajectories_discovery_heatmap_figs.input,



rule cluster_trajectories_discovery_heatmaps:
    input:
        rules.cluster_trajectories_discovery_heatmap_tables.input,
        rules.cluster_trajectories_discovery_heatmap_parameters.input,
        rules.cluster_trajectories_discovery_heatmap_figures.input
