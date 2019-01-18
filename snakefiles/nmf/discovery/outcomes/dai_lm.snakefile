# Disease activity outcome analysis using linear regression.

VISITS = config['discovery']['outcomes']['dai_lm']['visits']

ANALYSES = ['cluster_diagnoses', 'clusters', 'diagnoses', 'null']



# Input data for linear regression.

rule discovery_outcomes_dai_lm_data_pattern:
    output:
        'tables/discovery/outcomes/dai_lm/data/{analysis}/visit_{visit}.feather'
    input:
        'tables/discovery/outcomes/dai/data/{analysis}/visit_{visit}.feather'
    version:
        v('scripts/dai_lm/prepare_data.py')
    shell:
        'python scripts/dai_lm/prepare_data.py --input {input} --output {output}'



rule discovery_outcomes_dai_lm_data:
    input:
        expand(rules.discovery_outcomes_dai_lm_data_pattern.output, analysis=ANALYSES, visit=VISITS)



# Run linear regression.

rule discovery_outcomes_dai_lm_model_pattern:
    output:
        'tables/discovery/outcomes/dai_lm/models/{analysis}/visit_{visit}.rda'
    input:
        rules.discovery_outcomes_dai_lm_data_pattern.output
    version:
        v('scripts/dai_lm/do_lm.R')
    shell:
        'Rscript scripts/dai_lm/do_lm.R --input {input} --output {output}'



rule discovery_outcomes_dai_lm_models:
    input:
        expand(rules.discovery_outcomes_dai_lm_model_pattern.output, analysis=ANALYSES, visit=VISITS)



# Compare our models against the null model, which omits both cluster
# assignments and diagnoses.

rule discovery_outcomes_dai_lm_null_comparison_pattern:
    output:
        'tables/discovery/outcomes/dai_lm/null_comparison/{analysis}/visit_{visit}.txt'
    input:
        model=rules.discovery_outcomes_dai_lm_model_pattern.output,
        null=expand(rules.discovery_outcomes_dai_lm_model_pattern.output, analysis='null', visit='{visit}')
    version:
        v('scripts/dai_lm/compare_to_null.R')
    shell:
        'Rscript scripts/dai_lm/compare_to_null.R --model-input {input.model} --null-input {input.null} --output {output}'



rule discovery_outcomes_dai_lm_null_comparisons:
    input:
        expand(rules.discovery_outcomes_dai_lm_null_comparison_pattern.output, analysis=ANALYSES[:-1], visit=VISITS)



# Compare the fully specified model compared to clusters and diagnoses alone.

rule discovery_outcomes_dai_lm_single_cls_comparison_pattern:
    output:
        'tables/discovery/outcomes/dai_lm/cls_comparisons/{analysis}/visit_{visit}.txt'
    input:
        model=expand(rules.discovery_outcomes_dai_lm_model_pattern.output, analysis='cluster_diagnoses', visit='{visit}'),
        null=rules.discovery_outcomes_dai_lm_model_pattern.output
    version:
        v('scripts/dai_lm/compare_to_null.R')
    shell:
        'Rscript scripts/dai_lm/compare_to_null.R --model-input {input.model} --null-input {input.null} --output {output}'



rule discovery_outcomes_dai_lm_single_cls_comparisons:
    input:
        expand(rules.discovery_outcomes_dai_lm_single_cls_comparison_pattern.output, analysis=['clusters', 'diagnoses'], visit=VISITS)



# Extract results from linear regression.

rule discovery_outcomes_dai_lm_coefficient_pattern:
    output:
        'tables/discovery/outcomes/dai_lm/coefficients/{analysis}/visit_{visit}.csv'
    input:
        rules.discovery_outcomes_dai_lm_model_pattern.output
    version:
        v('scripts/dai_lm/get_coefficients.R')
    shell:
        'Rscript scripts/dai_lm/get_coefficients.R --input {input} --output {output}'



rule discovery_outcomes_dai_lm_coefficients:
    input:
        expand(rules.discovery_outcomes_dai_lm_coefficient_pattern.output, analysis=ANALYSES, visit=VISITS)



# Plots of significant coefficients.

rule discovery_outcomes_dai_lm_coefficient_figure_pattern:
    output:
        'figures/discovery/outcomes/dai_lm/coefficients/{analysis}/visit_{visit}.pdf'
    input:
        rules.discovery_outcomes_dai_lm_coefficient_pattern.output
    params:
        figure_width=3,
        figure_height=3
    version:
        v('scripts/dai_lm/plot_coefficients.R')
    shell:
        'Rscript scripts/dai_lm/plot_coefficients.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



rule discovery_outcomes_dai_lm_coefficient_figures:
    input:
        expand(rules.discovery_outcomes_dai_lm_coefficient_figure_pattern.output, analysis=ANALYSES, visit=VISITS)



# Targets.

rule discovery_outcomes_dai_lm_tables:
    input:
        rules.discovery_outcomes_dai_lm_data.input,
        rules.discovery_outcomes_dai_lm_models.input,
        rules.discovery_outcomes_dai_lm_single_cls_comparisons.input,
        rules.discovery_outcomes_dai_lm_null_comparisons.input,
        rules.discovery_outcomes_dai_lm_coefficients.input



rule discovery_outcomes_dai_lm_figures:
    input:
        rules.discovery_outcomes_dai_lm_coefficient_figures.input



rule discovery_outcomes_dai_lm:
    input:
        rules.discovery_outcomes_dai_lm_tables.input,
        rules.discovery_outcomes_dai_lm_figures.input
