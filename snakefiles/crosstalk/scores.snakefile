"""
Analyzes distributions of factor scores across patient groups.
"""

LOCALIZATIONS = ['full', 'partial']
LOCALIZATIONS_DIR = 'tables/localizations/assignments'
COHORT = ['discovery']
LEVELS = ['l1', 'l2']

# COUNTS = 'tables/site_counts/discovery/counts.csv'
COUNTS = 'inputs/crosstalk/scores/site_counts.csv'
SCORES = 'inputs/crosstalk/scores/scores/{level}.csv'
LOCALIZATIONS = 'inputs/crosstalk/scores/localizations/{level}.csv'

# Threshold patients in different ways based on median joint counts: either by
# median joint count across the entire cohort or median joint count per patient
# group.

COUNT_THRESHOLDS = ['cohort', 'cluster', 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]



# Link inputs.

rule crosstalk_scores_inputs_counts:
    output: COUNTS
    input: 'outputs/site_counts/discovery.csv'
    shell: LN



rule crosstalk_scores_inputs_scores_pattern:
    output: SCORES
    input: 'outputs/nmf/discovery/{level}/model/scores.csv'
    shell: LN



rule crosstalk_scores_inputs_scores:
    input:
        expand(rules.crosstalk_scores_inputs_scores_pattern.output, level=LEVELS),



rule crosstalk_scores_inputs_localizations_pattern:
    output: LOCALIZATIONS
    input: 'outputs/localizations/assignments/levels/discovery/{level}.csv'
    shell: LN



rule crosstalk_scores_inputs_localizations:
    input:
        expand(rules.crosstalk_scores_inputs_localizations_pattern.output, level=LEVELS),



rule crosstalk_scores_inputs:
    input:
        rules.crosstalk_scores_inputs_counts.output,
        rules.crosstalk_scores_inputs_scores.input,
        rules.crosstalk_scores_inputs_localizations.input,



# Prepare data for the following analyses.

rule crosstalk_scores_data_discovery_pattern:
    output: 'tables/crosstalk/data/{level}/discovery/{threshold}.feather'
    log: 'tables/crosstalk/data/{level}/discovery/{threshold}.log'
    benchmark: 'tables/crosstalk/data/{level}/discovery/{threshold}.txt'
    input:
        scores=SCORES,
        localizations=LOCALIZATIONS,
        counts=COUNTS,
    version: v('scripts/crosstalk/make_data.py')
    shell:
        'python scripts/crosstalk/make_data.py --score-input {input.scores} --localization-input {input.localizations} --count-input {input.counts} --threshold {wildcards.threshold} --output {output} --letters' + LOG



rule crosstalk_scores_data_discovery:
    input:
        expand(rules.crosstalk_scores_data_discovery_pattern.output, level=LEVELS, threshold=COUNT_THRESHOLDS),



# Plot distributions of scores across patient groups.

rule crosstalk_scores_distributions_fig_clusters_pattern:
    output: 'figures/crosstalk/scores/clusters/{level}/{cohort}/{threshold}.pdf'
    log: 'figures/crosstalk/scores/clusters/{level}/{cohort}/{threshold}.log'
    benchmark: 'figures/crosstalk/scores/clusters/{level}/{cohort}/{threshold}.txt'
    input: 'tables/crosstalk/data/{level}/{cohort}/{threshold}.feather'
    params:
        width=6,
        height=9,
        aspect_ratio=0.33,
        point_size=0.25,
        ncol=3,
    version: v('scripts/crosstalk/plot_distributions_groups.R')
    shell:
        'Rscript scripts/crosstalk/plot_distributions_groups.R --input {input} --output {output} --width {params.width} --height {params.height} --aspect-ratio {params.aspect_ratio} --point-size {params.point_size} --ncol {params.ncol}' + LOG



rule crosstalk_scores_distributions_fig_clusters:
    input:
        expand(rules.crosstalk_scores_distributions_fig_clusters_pattern.output, level=LEVELS, cohort=COHORT, threshold=COUNT_THRESHOLDS),



# Determine whether patient group assignments predict patient factor scores
# (they should).

rule crosstalk_scores_distributions_stats_pattern:
    output: 'tables/crosstalk/scores/stats/{level}/{cohort}/{threshold}.xlsx'
    log: 'tables/crosstalk/scores/stats/{level}/{cohort}/{threshold}.log'
    benchmark: 'tables/crosstalk/scores/stats/{level}/{cohort}/{threshold}.txt'
    input: 'tables/crosstalk/data/{level}/{cohort}/{threshold}.feather'
    version: v('scripts/crosstalk/scores/do_stats.R')
    shell:
        'Rscript scripts/crosstalk/scores/do_stats.R --input {input} --output {output}' + LOG



rule crosstalk_scores_distributions_stats:
    input:
        expand(rules.crosstalk_scores_distributions_stats_pattern.output, level=LEVELS, cohort=COHORT, threshold=COUNT_THRESHOLDS),



# Also conduct Z-tests.

rule crosstalk_scores_distributions_stats_z_pattern:
    output: 'tables/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.xlsx'
    log: 'tables/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.log'
    benchmark: 'tables/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.txt'
    input: 'tables/crosstalk/data/{level}/{cohort}/{threshold}.feather'
    version: v('scripts/crosstalk/scores/do_stats_z.R')
    shell:
        'Rscript scripts/crosstalk/scores/do_stats_z.R --input {input} --output {output}' + LOG



rule crosstalk_scores_distributions_stats_z:
    input:
        expand(rules.crosstalk_scores_distributions_stats_z_pattern.output, level=LEVELS, cohort=COHORT, threshold=COUNT_THRESHOLDS),


# Plot out Z-test results.

rule crosstalk_scores_distributions_stats_z_fig_pattern:
    output: 'figures/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.pdf'
    log: 'figures/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.log'
    benchmark: 'figures/crosstalk/scores/stats_z/{level}/{cohort}/{threshold}.txt'
    input: rules.crosstalk_scores_distributions_stats_z_pattern.output
    params:
        width=6,
        height=6,
        max_fdr=0.1,
        min_fdr=1e-16,
        option='B',
    version: v('scripts/crosstalk/scores/plot_z_tests.R')
    shell:
        'Rscript scripts/crosstalk/scores/plot_z_tests.R --input {input} --output {output} --width {params.width} --height {params.height} --min-fdr {params.min_fdr} --max-fdr {params.max_fdr} --option {params.option}' + LOG



rule crosstalk_scores_distributions_stats_z_fig:
    input:
        expand(rules.crosstalk_scores_distributions_stats_z_fig_pattern.output, level=LEVELS, cohort=COHORT, threshold=COUNT_THRESHOLDS),



# Targets.

rule crosstalk_scores_tables:
    input:
        rules.crosstalk_scores_data_discovery.input,
        rules.crosstalk_scores_distributions_stats.input,
        rules.crosstalk_scores_distributions_stats_z.input,



rule crosstalk_scores_parameters:
    input:



rule crosstalk_scores_figures:
    input:
        rules.crosstalk_scores_distributions_fig_clusters.input,
        rules.crosstalk_scores_distributions_stats_z_fig.input,



rule crosstalk_scores:
    input:
        rules.crosstalk_scores_inputs.input,
        rules.crosstalk_scores_tables.input,
        rules.crosstalk_scores_parameters.input,
        rules.crosstalk_scores_figures.input
