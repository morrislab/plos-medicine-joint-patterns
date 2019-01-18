"""
Time-to-zero analyses in the validation cohort.
"""

import itertools as it

DIAGNOSES = 'inputs/outcomes/time_to_zero/validation/diagnoses.csv'
LOCALIZATIONS = 'inputs/outcomes/time_to_zero/validation/localizations.csv'
JOINTS = 'inputs/outcomes/time_to_zero/validation/joints.feather'

COHORT = 'validation'
MAX_VISIT = config.outcomes.time_to_zero.max_visit

ANALYSES = [
    'classification',
    'localization',
    'diagnosis',
    'classification_localization',
    'classification_diagnosis',
    'classification_localization_diagnosis',
]

COMPARISONS = [('null', analysis) for analysis in ANALYSES] + [
    ('classification', a) for a in ANALYSES
    if a != 'classification' and 'classification' in a
] + [
    ('localization', a) for a in ANALYSES
    if a != 'localization' and 'localization' in a
] + [
    ('diagnosis', a) for a in ANALYSES if a != 'diagnosis' and 'diagnosis' in a
] + [('classification_localization', 'classification_localization_diagnosis'),
     ('classification_diagnosis', 'classification_localization_diagnosis')]

COMPARISONS = ['__'.join(tup) for tup in COMPARISONS]

CLASSIFICATION_TYPES = ['classification', 'diagnosis']



# Link inputs.

rule outcomes_time_to_zero_validation_inputs_diagnoses:
    output: DIAGNOSES
    input: 'outputs/diagnoses/roots/validation.csv'
    shell: LN



rule outcomes_time_to_zero_validation_inputs_localizations:
    output: LOCALIZATIONS
    input: 'outputs/localizations/assignments/validation.csv'
    shell: LN



rule outcomes_time_to_zero_validation_inputs_joints:
    output: JOINTS
    input: 'outputs/data/validation/joints.feather'
    shell: LN



rule outcomes_time_to_zero_validation_inputs:
    input:
        DIAGNOSES,
        LOCALIZATIONS,
        JOINTS,



# Generate hazard data.

rule outcomes_time_to_zero_validation_hazard_data:
    output: 'tables/outcomes/time_to_zero/validation/hazards/data.feather'
    log: 'tables/outcomes/time_to_zero/validation/hazards/data.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/data.txt'
    input:
        diagnoses=DIAGNOSES,
        localizations=LOCALIZATIONS,
        sites=JOINTS,
    params:
        max_visit=MAX_VISIT
    version: v('scripts/outcomes/time_to_zero/get_hazard_data.py')
    shell:
        'python scripts/outcomes/time_to_zero/get_hazard_data.py --site-input {input.sites} --localization-input {input.localizations} --diagnosis-input {input.diagnoses} --output {output} --max-visit {params.max_visit}' + LOG



# Generate hazard plots.

rule outcomes_time_to_zero_validation_hazards:
    output: 'figures/outcomes/time_to_zero/validation/hazards.pdf'
    log: 'figures/outcomes/time_to_zero/validation/hazards.log'
    benchmark: 'figures/outcomes/time_to_zero/validation/hazards.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    params:
        width=9,
        height=6,
    version: v('scripts/outcomes/time_to_zero/plot_hazard_data.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/plot_hazard_data.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



# Generate the Cox proportional hazards models.

rule outcomes_time_to_zero_validation_coxph_null:
    output: 'tables/outcomes/time_to_zero/validation/hazards/models/null.rda'
    log: 'tables/outcomes/time_to_zero/validation/hazards/models/null.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/models/null.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    version: v('scripts/outcomes/time_to_zero/make_coxph_model.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/make_coxph_model.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_pattern:
    output: 'tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.rda'
    log: 'tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    params:
        include=lambda wildcards: wildcards.analysis.split('_'),
    version: v('scripts/outcomes/time_to_zero/make_coxph_model.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/make_coxph_model.R --input {input} --output {output} --include {params.include}' + LOG



rule outcomes_time_to_zero_validation_coxph:
    input:
        expand(rules.outcomes_time_to_zero_validation_coxph_pattern.output, analysis=ANALYSES),
        rules.outcomes_time_to_zero_validation_coxph_null.output,



rule outcomes_time_to_zero_validation_coxph_stats_pattern:
    output: 'tables/outcomes/time_to_zero/validation/hazards/stats/{analysis}.txt'
    log: 'tables/outcomes/time_to_zero/validation/hazards/stats/{analysis}.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/stats/{analysis}.benchmark.txt'
    input: 'tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.rda'
    version: v('scripts/outcomes/time_to_zero/get_coxph_stats.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/get_coxph_stats.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_stats:
    input:
        expand(rules.outcomes_time_to_zero_validation_coxph_stats_pattern.output, analysis=ANALYSES),



# Compare individual models to see if adding different types of terms improves
# our ability to predict time to zero.

def split_comparison_validation(wildcards):
    parts = wildcards.comparison.split('__', 1)
    return {'reference': expand('tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.rda', analysis=parts[0]), 'alternative': expand('tables/outcomes/time_to_zero/validation/hazards/models/{analysis}.rda', analysis=parts[1])}

rule outcomes_time_to_zero_validation_comparison_pattern:
    output: 'tables/outcomes/time_to_zero/validation/hazards/comparisons/{comparison}.txt'
    log: 'tables/outcomes/time_to_zero/validation/hazards/comparisons/{comparison}.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/comparisons/{comparison}benchmark.txt'
    input: unpack(split_comparison_validation)
    version: v('scripts/outcomes/time_to_zero/compare_models.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/compare_models.R --reference-input {input.reference} --alternative-input {input.alternative} --output {output}' + LOG



rule outcomes_time_to_zero_validation_comparisons:
    input:
        expand(rules.outcomes_time_to_zero_validation_comparison_pattern.output, comparison=COMPARISONS),



# Plot hazard curves.

rule outcomes_time_to_zero_validation_coxph_curve_data_clusters:
    output: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/clusters.feather',
    log: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/clusters.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/clusters.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    version: v('scripts/outcomes/time_to_zero/get_curve_data_clusters.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/get_curve_data_clusters.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_curve_data_localizations:
    output: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/localizations.feather'
    log: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/localizations.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/localizations.benchmark'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    version: v('scripts/outcomes/time_to_zero/get_curve_data_localizations.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/get_curve_data_localizations.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_curve_data_cluster_localizations:
    output: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/cluster_localizations.feather'
    log: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/cluster_localizations.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/cluster_localizations.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    version: v('scripts/outcomes/time_to_zero/get_curve_data_cluster_localizations.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/get_curve_data_cluster_localizations.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_curve_data_diagnoses:
    output: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/diagnoses.feather'
    log: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/diagnoses.log'
    benchmark: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/diagnoses.txt'
    input: rules.outcomes_time_to_zero_validation_hazard_data.output
    version: v('scripts/outcomes/time_to_zero/get_curve_data_diagnoses.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/get_curve_data_diagnoses.R --input {input} --output {output}' + LOG



rule outcomes_time_to_zero_validation_coxph_curve_data:
    input:
        rules.outcomes_time_to_zero_validation_coxph_curve_data_clusters.output,
        rules.outcomes_time_to_zero_validation_coxph_curve_data_localizations.output,
        rules.outcomes_time_to_zero_validation_coxph_curve_data_cluster_localizations.output,
        rules.outcomes_time_to_zero_validation_coxph_curve_data_diagnoses.output,



STRATA_VALIDATION = {
    'clusters': 'classification',
    'diagnoses': 'diagnosis',
    'localizations': 'localization'
}

rule outcomes_time_to_zero_validation_coxph_curves_fig_pattern:
    output: 'figures/outcomes/time_to_zero/validation/hazards/curves/{analysis}.pdf'
    log: 'figures/outcomes/time_to_zero/validation/hazards/curves/{analysis}.log'
    benchmark: 'figures/outcomes/time_to_zero/validation/hazards/curves/{analysis}.txt'
    input: 'tables/outcomes/time_to_zero/validation/hazards/curve_data/{analysis}.feather'
    params:
        width=6,
        height=3,
    version: v('scripts/outcomes/time_to_zero/plot_curves.R')
    run:
        stratum = STRATA_VALIDATION[wildcards.analysis]
        shell('Rscript scripts/outcomes/time_to_zero/plot_curves.R --input {input} --stratum {stratum} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG)



rule outcomes_time_to_zero_validation_coxph_curves_fig_cluster_localizations:
    output: 'figures/outcomes/time_to_zero/validation/hazards/curves/cluster_localizations.pdf'
    log: 'figures/outcomes/time_to_zero/validation/hazards/curves/cluster_localizations.log'
    benchmark: 'figures/outcomes/time_to_zero/validation/hazards/curves/cluster_localizations.txt'
    input: rules.outcomes_time_to_zero_validation_coxph_curve_data_cluster_localizations.output
    params:
        width=6,
        height=3,
    version: v('scripts/outcomes/time_to_zero/plot_curves_cluster_localizations.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/plot_curves_cluster_localizations.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



# Overlapping curves.

rule outcomes_time_to_zero_validation_coxph_curves_fig_clusters_merged:
    output: 'figures/outcomes/time_to_zero/validation/hazards/curves/clusters_merged.pdf'
    log: 'figures/outcomes/time_to_zero/validation/hazards/curves/clusters_merged.log'
    benchmark: 'figures/outcomes/time_to_zero/validation/hazards/curves/clusters_merged.txt'
    input: rules.outcomes_time_to_zero_validation_coxph_curve_data_clusters.output
    params:
        width=3,
        height=3,
    version: v('scripts/outcomes/time_to_zero/plot_curves_clusters_merged.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/plot_curves_clusters_merged.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule outcomes_time_to_zero_validation_coxph_curves_fig_localizations_merged:
    output: 'figures/outcomes/time_to_zero/validation/hazards/curves/localizations_merged.pdf'
    log: 'figures/outcomes/time_to_zero/validation/hazards/curves/localizations_merged.log'
    benchmark: 'figures/outcomes/time_to_zero/validation/hazards/curves/localizations_merged.txt'
    input: rules.outcomes_time_to_zero_validation_coxph_curve_data_localizations.output
    params:
        width=3,
        height=3,
    version: v('scripts/outcomes/time_to_zero/plot_curves_localizations_merged.R')
    shell:
        'Rscript scripts/outcomes/time_to_zero/plot_curves_localizations_merged.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule outcomes_time_to_zero_validation_coxph_curves_fig:
    input:
        expand(
            rules.outcomes_time_to_zero_validation_coxph_curves_fig_pattern.output,
            analysis=['clusters', 'diagnoses', 'localizations']),
        rules.outcomes_time_to_zero_validation_coxph_curves_fig_cluster_localizations.output,
        rules.outcomes_time_to_zero_validation_coxph_curves_fig_clusters_merged.output,
        rules.outcomes_time_to_zero_validation_coxph_curves_fig_localizations_merged.output,



# Targets.

rule outcomes_time_to_zero_validation_tables:
    input:
        rules.outcomes_time_to_zero_validation_hazard_data.output,
        rules.outcomes_time_to_zero_validation_coxph.input,
        rules.outcomes_time_to_zero_validation_coxph_stats.input,
        rules.outcomes_time_to_zero_validation_comparisons.input,
        rules.outcomes_time_to_zero_validation_coxph_curve_data.input,



rule outcomes_time_to_zero_validation_parameters:
    input:



rule outcomes_time_to_zero_validation_figures:
    input:
        rules.outcomes_time_to_zero_validation_hazards.output,
        rules.outcomes_time_to_zero_validation_coxph_curves_fig.input,



rule outcomes_time_to_zero_validation:
    input:
        rules.outcomes_time_to_zero_validation_tables.input,
        rules.outcomes_time_to_zero_validation_parameters.input,
        rules.outcomes_time_to_zero_validation_figures.input,
