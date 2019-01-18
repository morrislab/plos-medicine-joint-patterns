"""
Cluster trajectories but including RF status.
"""

COHORTS = 'discovery'

# Trajectory analysis data for the discovery cohort.

MAX_VISIT = config['cluster_trajectories']['discovery']['max_visit']
BATCHES = Box({cohort: list(range(1, values.batches + 1)) for cohort, values in config.cluster_trajectories.rf.permutation_test.items()})
LOCALIZATIONS = ['limited', 'partial', 'undifferentiated']



# Arrange inputs.

rule cluster_trajectories_rf_sources_scores_discovery:
    output: 'tables/cluster_trajectories/rf/sources/scores/discovery.csv'
    input: 'tables/cluster_trajectories/discovery/full/cohort/scores.csv'
    shell: LN



rule cluster_trajectories_rf_sources_scores:
    input:
        expand('tables/cluster_trajectories/rf/sources/scores/{cohort}.csv', cohort=COHORTS),



# For each visit, determine patient group assignments.

rule cluster_trajectories_rf_clusters_pattern:
    output: 'tables/cluster_trajectories/rf/clusters/{cohort}.csv'
    log: 'tables/cluster_trajectories/rf/clusters/{cohort}.log'
    benchmark: 'tables/cluster_trajectories/rf/clusters/{cohort}.txt'
    input:
        baseline_clusters='tables/localizations/rf/unified/{cohort}.csv',
        scores='tables/cluster_trajectories/rf/sources/scores/{cohort}.csv',
    version: v('scripts/group_trajectories/get_group_trajectories.py')
    shell:
        'python scripts/group_trajectories/get_group_trajectories.py --baseline-cluster-input {input.baseline_clusters} --score-input {input.scores} --output {output}' + LOG



rule cluster_trajectories_rf_clusters:
    input:
        expand(rules.cluster_trajectories_rf_clusters_pattern.output, cohort=COHORTS),



# Data to plot, split by both localization and RF.

rule cluster_trajectories_rf_heatmap_data_pattern:
    output: 'tables/cluster_trajectories/rf/heatmap/base/{cohort}.csv'
    log: 'tables/cluster_trajectories/rf/heatmap/base/{cohort}.log'
    benchmark: 'tables/cluster_trajectories/rf/heatmap/base/{cohort}.txt'
    input: rules.cluster_trajectories_rf_clusters_pattern.output
    version: v('scripts/group_trajectories/rf/get_heatmap_data.py')
    shell:
        'python scripts/group_trajectories/rf/get_heatmap_data.py --input {input} --output {output}' + LOG



rule cluster_trajectories_rf_heatmap_data:
    input:
        expand(rules.cluster_trajectories_rf_heatmap_data_pattern.output, cohort=COHORTS),



# Split the data for plotting.

rule cluster_trajectories_rf_heatmap_data_split_pattern:
    output: 'tables/cluster_trajectories/rf/heatmap/localized/{cohort}/{localization}.csv'
    log: 'tables/cluster_trajectories/rf/heatmap/localized/{cohort}/{localization}.log'
    benchmark: 'tables/cluster_trajectories/rf/heatmap/localized/{cohort}/{localization}.txt'
    input: rules.cluster_trajectories_rf_heatmap_data_pattern.output
    shell:
        "head -n 1 {input} > {output} && awk '/_{wildcards.localization}/' {input} >> {output}"



rule cluster_trajectories_rf_heatmap_data_split:
    input:
        expand(rules.cluster_trajectories_rf_heatmap_data_split_pattern.output, cohort=COHORTS, localization=LOCALIZATIONS),



# Generate seeds for the permutation test.

rule cluster_trajectories_rf_permutation_test_seeds_discovery:
    output:
        expand('tables/cluster_trajectories/rf/permutation_test/seeds/discovery/{batch}.txt', batch=BATCHES.discovery),
        flag=touch('tables/cluster_trajectories/rf/permutation_test/seeds/discovery/seeds.done')
    benchmark: 'tables/cluster_trajectories/rf/permutation_test/seeds/discovery/seeds.txt'
    log: 'tables/cluster_trajectories/rf/permutation_test/seeds/discovery/seeds.log'
    params:
        batches=config.cluster_trajectories.rf.permutation_test.discovery.batches,
        permutations_per_batch=config.cluster_trajectories.rf.permutation_test.discovery.permutations_per_batch,
        seed=config.cluster_trajectories.rf.permutation_test.discovery.seed,
        prefix='tables/cluster_trajectories/rf/permutation_test/seeds/discovery/'
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.prefix} --jobs {params.batches} --iterations-per-job {params.permutations_per_batch} --seed {params.seed}' + LOG



rule cluster_trajectories_rf_permutation_test_seeds:
    input:
        rules.cluster_trajectories_rf_permutation_test_seeds_discovery.output,



# Generate permutation test samples.

rule cluster_trajectories_rf_permutation_test_samples_pattern:
    output: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{cohort}/{batch}.feather'
    log: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{cohort}/{batch}.log'
    benchmark: 'tables/cluster_trajectories/discovery/heatmap/permutation_test/samples/{cohort}/{batch}.txt'
    input:
        data=rules.cluster_trajectories_rf_clusters_pattern.output,
        seedlist='tables/cluster_trajectories/rf/permutation_test/seeds/{cohort}/{batch}.txt',
        flags='tables/cluster_trajectories/rf/permutation_test/seeds/{cohort}/seeds.done',
    version: v('scripts/group_trajectories/get_permutation_samples_any.py')
    shell:
        'python scripts/group_trajectories/get_permutation_samples_any.py --input {input.data} --seedlist {input.seedlist} --output {output}' + LOG



rule cluster_trajectories_rf_permutation_test_samples:
    input:
        expand(rules.cluster_trajectories_rf_permutation_test_samples_pattern.output, cohort='discovery', batch=BATCHES.discovery),



# Concatenate the samples.

rule cluster_trajectories_rf_permutation_test_concatenated_pattern:
    output: 'tables/cluster_trajectories/rf/permutation_test/concatenated/{cohort}.feather'
    log: 'tables/cluster_trajectories/rf/permutation_test/concatenated/{cohort}.log'
    benchmark: 'tables/cluster_trajectories/rf/permutation_test/concatenated/{cohort}.txt'
    input: lambda wildcards: expand(rules.cluster_trajectories_rf_permutation_test_samples_pattern.output, cohort=wildcards.cohort, batch=BATCHES[wildcards.cohort])
    version: v('scripts/group_trajectories/concatenate_permutation_samples_any.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/group_trajectories/concatenate_permutation_samples_any.py --output {output} {inputs}' + LOG)



rule cluster_trajectories_rf_permutation_test_concatenated:
    input:
        expand(rules.cluster_trajectories_rf_permutation_test_concatenated_pattern.output, cohort=COHORTS),



# Generate statistics.

rule cluster_trajectories_rf_permutation_test_stats_pattern:
    output: 'tables/cluster_trajectories/rf/permutation_test/stats/{cohort}.csv'
    log: 'tables/cluster_trajectories/rf/permutation_test/stats/{cohort}.log'
    benchmark: 'tables/cluster_trajectories/rf/permutation_test/stats/{cohort}.txt'
    input:
        probabilities=rules.cluster_trajectories_rf_heatmap_data_pattern.output,
        concatenated=rules.cluster_trajectories_rf_permutation_test_concatenated_pattern.output,
    version: v('scripts/group_trajectories/get_permutation_p_values.py')
    shell:
        'python scripts/group_trajectories/get_permutation_p_values.py --probability-input {input.probabilities} --sample-input {input.concatenated} --output {output}' + LOG



rule cluster_trajectories_rf_permutation_test_stats:
    input:
        expand(rules.cluster_trajectories_rf_permutation_test_stats_pattern.output, cohort=COHORTS),



# Generate the figures.

rule cluster_trajectories_rf_permutation_test_heatmap_pattern:
    output: 'figures/cluster_trajectories/rf/heatmap/{cohort}/{localization}.pdf'
    log: 'figures/cluster_trajectories/rf/heatmap/{cohort}/{localization}.log'
    benchmark: 'figures/cluster_trajectories/rf/heatmap/{cohort}/{localization}.txt'
    input:
        data=rules.cluster_trajectories_rf_heatmap_data_split_pattern.output,
        stats=rules.cluster_trajectories_rf_permutation_test_stats_pattern.output,
    params:
        width=6,
        height=2.5,
        option='B',
    version: v('scripts/group_trajectories/plot_heatmap.R')
    shell:
        'Rscript scripts/group_trajectories/plot_heatmap.R --input {input.data} --stats-input {input.stats} --output {output} --width {params.width} --height {params.height} --colour-scale --option {params.option}' + LOG



rule cluster_trajectories_rf_permutation_test_heatmap:
    input:
        expand(rules.cluster_trajectories_rf_permutation_test_heatmap_pattern.output, cohort=COHORTS, localization=LOCALIZATIONS),



# Targets.

rule cluster_trajectories_rf_tables:
    input:
        rules.cluster_trajectories_rf_clusters.input,
        rules.cluster_trajectories_rf_heatmap_data.input,
        rules.cluster_trajectories_rf_heatmap_data_split.input,
        rules.cluster_trajectories_rf_permutation_test_seeds.input,
        rules.cluster_trajectories_rf_permutation_test_samples.input,
        rules.cluster_trajectories_rf_permutation_test_concatenated.input,
        rules.cluster_trajectories_rf_permutation_test_stats.input,



rule cluster_trajectories_rf_parameters:
    input:



rule cluster_trajectories_rf_figures:
    input:
        rules.cluster_trajectories_rf_permutation_test_heatmap.input,



rule cluster_trajectories_rf:
    input:
        rules.cluster_trajectories_rf_tables.input,
        rules.cluster_trajectories_rf_parameters.input,
        rules.cluster_trajectories_rf_figures.input,