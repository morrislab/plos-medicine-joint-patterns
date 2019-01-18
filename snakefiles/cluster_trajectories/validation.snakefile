"""
Cluster trajectories for the validation cohort.

This analysis uses validation data projected onto discovery patient groups and degrees
of localization.
"""

COHORT = 'validation'
LOCALIZATIONS = ['localized', 'partial', 'extended']

PARAMS = config.cluster_trajectories.validation

MAX_VISIT = PARAMS.max_visit
BATCHES = PARAMS.permutation_test.batches
BATCH_NUMBERS = list(range(1, BATCHES + 1))

DATA = 'inputs/cluster_trajectories/validation/joints.feather'
PARAMETERS = 'inputs/cluster_trajectories/validation/scaled/parameters/{level}.csv'
PARAMETERS_L1 = expand(PARAMETERS, level='l1')
PARAMETERS_L2 = expand(PARAMETERS, level='l2')
MODEL = 'inputs/cluster_trajectories/validation/models/{level}.pkl'
MODEL_L1 = expand(MODEL, level='l1')
MODEL_L2 = expand(MODEL, level='l2')
BASELINE_CLUSTERS = 'inputs/cluster_trajectories/validation/clusters/baseline.csv'
BASELINE_LOCALIZATIONS = 'inputs/cluster_trajectories/validation/localizations/baseline.csv'


# Link inputs.

rule cluster_trajectories_validation_inputs_data:
    output: DATA
    input: 'outputs/data/validation/joints.feather'
    shell: LN



rule cluster_trajectories_validation_inputs_parameters_pattern:
    output: PARAMETERS
    input: 'outputs/nmf/discovery/{level}/scaled/parameters.csv'
    shell: LN



rule cluster_trajectories_validation_inputs_models_pattern:
    output: MODEL
    input: 'outputs/nmf/discovery/{level}/model/model.pkl'
    shell: LN



rule cluster_trajectories_validation_inputs_clusters:
    output: BASELINE_CLUSTERS
    input: 'outputs/validation_projections/clusters.csv'
    shell: LN



rule cluster_trajectories_validation_inputs_localizations:
    output: BASELINE_LOCALIZATIONS
    input: 'outputs/validation_projections/localizations/unified.csv'
    shell: LN



rule cluster_trajectories_validation_inputs:
    input:
        rules.cluster_trajectories_validation_inputs_data.output,
        expand(rules.cluster_trajectories_validation_inputs_parameters_pattern.output, level=['l1', 'l2']),
        expand(rules.cluster_trajectories_validation_inputs_models_pattern.output, level=['l1', 'l2']),
        rules.cluster_trajectories_validation_inputs_clusters.output,
        rules.cluster_trajectories_validation_inputs_localizations.output,



# Generate scores.

rule cluster_trajectories_validation_scores:
    output: 'tables/cluster_trajectories/validation/scores.csv'
    log: 'tables/cluster_trajectories/validation/scores.log'
    benchmark: 'tables/cluster_trajectories/validation/scores.txt'
    input:
        data=DATA,
        parameters_l1=PARAMETERS_L1,
        parameters_l2=PARAMETERS_L2,
        model_l1=MODEL_L1,
        model_l2=MODEL_L2,
    params:
        max_visit=MAX_VISIT,
    version: v('scripts/group_trajectories/get_score_trajectories_all.py')
    shell:
        'python scripts/group_trajectories/get_score_trajectories_all.py --joint-data-input {input.data} --scaling-parameter-input {input.parameters_l1} --scaling-parameter-input {input.parameters_l2} --nmf-model-input {input.model_l1} --nmf-model-input {input.model_l2} --output {output} --max-visit {params.max_visit}' + LOG



# Generate cluster assignments.

rule cluster_trajectories_validation_clusters:
    output: 'tables/cluster_trajectories/validation/clusters/localized.csv'
    log: 'tables/cluster_trajectories/validation/clusters/localized.log'
    benchmark: 'tables/cluster_trajectories/validation/clusters/localized.txt'
    input:
        baseline_clusters=BASELINE_LOCALIZATIONS,
        scores=rules.cluster_trajectories_validation_scores.output,
    version: v('scripts/group_trajectories/get_group_trajectories.py')
    shell:
        'python scripts/group_trajectories/get_group_trajectories.py --baseline-cluster-input {input.baseline_clusters} --score-input {input.scores} --output {output}' + LOG



# Generate heat map data.

rule cluster_trajectories_validation_heatmap_data_calculated:
    output: 'tables/cluster_trajectories/validation/heatmap/data.csv'
    log: 'tables/cluster_trajectories/validation/heatmap/data.log'
    benchmark: 'tables/cluster_trajectories/validation/heatmap/data.txt'
    input: rules.cluster_trajectories_validation_clusters.output
    version: v('scripts/group_trajectories/get_heatmap_data_any.py')
    shell:
        'python scripts/group_trajectories/get_heatmap_data_any.py --input {input} --output {output}' + LOG



rule cluster_trajectories_validation_heatmap_data_localized_pattern:
    output: 'tables/cluster_trajectories/validation/heatmap/data/{localization}.csv'
    input: rules.cluster_trajectories_validation_heatmap_data_calculated.output
    shell:
        "head -n 1 {input} > {output} && awk '/_{wildcards.localization}/' {input} >> {output}"



rule cluster_trajectories_validation_heatmap_data:
    input:
        expand(rules.cluster_trajectories_validation_heatmap_data_localized_pattern.output, localization=LOCALIZATIONS),



# Generate seeds for the permutation test.

rule cluster_trajectories_validation_heatmap_stats_seeds:
    output:
        expand('tables/cluster_trajectories/validation/heatmap/permutation_test/seeds/{batch}.txt', batch=BATCH_NUMBERS),
        flag=touch('tables/cluster_trajectories/validation/heatmap/permutation_test/seeds.done')
    log: 'tables/cluster_trajectories/validation/heatmap/permutation_test/seeds.log'
    benchmark: 'tables/cluster_trajectories/validation/heatmap/permutation_test/seeds.txt'
    params:
        batches=PARAMS.permutation_test.batches,
        permutations_per_batch=PARAMS.permutation_test.permutations_per_batch,
        seed=PARAMS.permutation_test.seed,
        prefix='tables/cluster_trajectories/validation/heatmap/permutation_test/seeds/',
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.prefix} --jobs {params.batches} --iterations-per-job {params.permutations_per_batch} --seed {params.seed}' + LOG



# Generate permutation test samples.

rule cluster_trajectories_validation_heatmap_stats_samples_pattern:
    output: 'tables/cluster_trajectories/validation/heatmap/permutation_test/samples/{localization}/{batch}.feather'
    log: 'tables/cluster_trajectories/validation/heatmap/permutation_test/samples/{localization}/{batch}.log'
    benchmark: 'tables/cluster_trajectories/validation/heatmap/permutation_test/samples/{localization}/{batch}.txt'
    input:
        rules.cluster_trajectories_validation_heatmap_stats_seeds.output.flag,
        data=rules.cluster_trajectories_validation_heatmap_data_calculated.input,
        seedlist='tables/cluster_trajectories/validation/heatmap/permutation_test/seeds/{batch}.txt',
    version: v('scripts/group_trajectories/get_permutation_samples_any.py')
    shell:
        'python scripts/group_trajectories/get_permutation_samples_any.py --input {input.data} --seedlist {input.seedlist} --output {output}' + LOG



rule cluster_trajectories_validation_heatmap_stats_samples:
    input:
        expand(rules.cluster_trajectories_validation_heatmap_stats_samples_pattern.output, localization=LOCALIZATIONS, batch=BATCH_NUMBERS),



# Concatenate the samples.

rule cluster_trajectories_validation_heatmap_stats_concatenated_pattern:
    output: 'tables/cluster_trajectories/validation/heatmap/permutation_test/concatenated/{localization}.feather'
    log: 'tables/cluster_trajectories/validation/heatmap/permutation_test/concatenated/{localization}.log'
    benchmark: 'tables/cluster_trajectories/validation/heatmap/permutation_test/concatenated/{localization}.txt'
    input: expand(rules.cluster_trajectories_validation_heatmap_stats_samples_pattern.output, localization='{localization}', batch=BATCH_NUMBERS),
    version: v('scripts/group_trajectories/concatenate_permutation_samples_any.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/group_trajectories/concatenate_permutation_samples_any.py {inputs} --output {output}' + LOG)



rule cluster_trajectories_validation_heatmap_stats_concatenated:
    input:
        expand(rules.cluster_trajectories_validation_heatmap_stats_concatenated_pattern.output, localization=LOCALIZATIONS),



# Generate statistics.

rule cluster_trajectories_validation_heatmap_stats_pattern:
    output: 'tables/cluster_trajectories/validation/heatmap/permutation_test/p_values/{localization}.csv'
    log: 'tables/cluster_trajectories/validation/heatmap/permutation_test/p_values/{localization}.log'
    log: 'tables/cluster_trajectories/validation/heatmap/permutation_test/p_values/{localization}.txt'
    input:
        probabilities=rules.cluster_trajectories_validation_heatmap_data_calculated.output,
        concatenated=rules.cluster_trajectories_validation_heatmap_stats_concatenated_pattern.output,
    version: v('scripts/group_trajectories/get_permutation_p_values.py')
    shell:
        'python scripts/group_trajectories/get_permutation_p_values.py --probability-input {input.probabilities} --sample-input {input.concatenated} --output {output}' + LOG



rule cluster_trajectories_validation_heatmap_stats:
    input:
        expand(rules.cluster_trajectories_validation_heatmap_stats_pattern.output, localization=LOCALIZATIONS)



# Generate figures.

rule cluster_trajectories_validation_heatmap_fig_localized_pattern:
    output: 'figures/cluster_trajectories/validation/heatmap/{localization}.pdf'
    log: 'figures/cluster_trajectories/validation/heatmap/{localization}.log'
    benchmark: 'figures/cluster_trajectories/validation/heatmap/{localization}.txt'
    input:
        data=rules.cluster_trajectories_validation_heatmap_data_localized_pattern.output,
        stats=rules.cluster_trajectories_validation_heatmap_stats_pattern.output,
    params:
        width=6,
        height=2.5,
    version: v('scripts/group_trajectories/plot_heatmaps.R')
    shell:
        'Rscript scripts/group_trajectories/plot_heatmap.R --input {input.data} --stats-input {input.stats} --output {output} --width {params.width} --height {params.height} --colour-scale --option B' + LOG



rule cluster_trajectories_validation_heatmap_fig:
    input:
        expand(rules.cluster_trajectories_validation_heatmap_fig_localized_pattern.output, localization=LOCALIZATIONS),



# Targets.

rule cluster_trajectories_validation_tables:
    input:
        rules.cluster_trajectories_validation_scores.output,
        rules.cluster_trajectories_validation_clusters.output,
        rules.cluster_trajectories_validation_heatmap_data.input,
        rules.cluster_trajectories_validation_heatmap_stats_seeds.output,
        rules.cluster_trajectories_validation_heatmap_stats_samples.input,
        rules.cluster_trajectories_validation_heatmap_stats_concatenated.input,
        rules.cluster_trajectories_validation_heatmap_stats.input,



rule cluster_trajectories_validation_parameters:
    input:



rule cluster_trajectories_validation_figures:
    input:
        rules.cluster_trajectories_validation_heatmap_fig.input,



rule cluster_trajectories_validation:
    input:
        rules.cluster_trajectories_validation_inputs.input,
        rules.cluster_trajectories_validation_tables.input,
        rules.cluster_trajectories_validation_parameters.input,
        rules.cluster_trajectories_validation_figures.input,
