# Forward stepwise regression.

DISCOVERY_NMF_OUTCOMES_FSR_N = config['discovery']['nmf']['l2']['n']


VISITS = config['discovery']['outcomes']['fsr']['visits']

ANALYSES = ['cluster_diagnoses', 'clusters', 'diagnoses', 'null']



# Input data for FSR.

rule discovery_outcomes_fsr_data_pattern:
    output:
        'tables/discovery/outcomes/fsr/data/{analysis}/visit_{visit}.feather'
    input:
        'tables/discovery/outcomes/dai/data/{analysis}/visit_{visit}.feather'
    version:
        v('scripts/fsr/prepare_data.py')
    shell:
        'python scripts/fsr/prepare_data.py --input {input} --output {output}'



rule discovery_outcomes_fsr_data:
    input:
        expand(rules.discovery_outcomes_fsr_data_pattern.output, analysis=ANALYSES, visit=VISITS)



# Run FSR.

rule discovery_outcomes_fsr_trace_pattern:
    output:
        'tables/discovery/outcomes/fsr/traces/{analysis}/visit_{visit}.rda'
    input:
        rules.discovery_outcomes_fsr_data_pattern.output
    version:
        v('scripts/fsr/predict_dai.R')
    shell:
        'Rscript scripts/fsr/predict_dai.R --input {input} --output {output}'



rule discovery_outcomes_fsr_traces:
    input:
        expand(rules.discovery_outcomes_fsr_trace_pattern.output, analysis=ANALYSES, visit=VISITS)



# Number of coefficients by P-value.

rule nmf_discovery_outcomes_fsr_n_coefficients_pattern:
    output:
        'figures/discovery/outcomes/fsr/n_coefficients/{analysis}/visit_{visit}.pdf'
    input:
        rules.discovery_outcomes_fsr_trace_pattern.output
    params:
        figure_width=3,
        figure_height=3,
    version:
        v('scripts/fsr/plot_num_coefficients.R')
    shell:
        'Rscript scripts/fsr/plot_num_coefficients.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



rule nmf_discovery_outcomes_fsr_n_coefficients:
    input:
        expand(rules.nmf_discovery_outcomes_fsr_n_coefficients_pattern.output, analysis=ANALYSES, visit=VISITS)



rule nmf_discovery_outcomes_fsr_coefficient_pattern:
    output:
        'figures/discovery/outcomes/fsr/coefficients/{analysis}/visit_{visit}.pdf'
    input:
        rules.discovery_outcomes_fsr_trace_pattern.output
    params:
        figure_width=6,
        figure_height=6,
        alpha=0.05
    version:
        v('scripts/fsr/plot_dai_fs_coefficients.R')
    shell:
        'Rscript scripts/fsr/plot_dai_fs_coefficients.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height} --alpha {params.alpha}'



rule nmf_discovery_outcomes_fsr_coefficients:
    input:
        expand(rules.nmf_discovery_outcomes_fsr_coefficient_pattern.output, analysis=ANALYSES, visit=VISITS)



rule nmf_discovery_outcomes_fsr_coefficient_k_pattern:
    output:
        'figures/discovery/outcomes/fsr/coefficients_k/{analysis}/visit_{visit}.pdf'
    input:
        rules.discovery_outcomes_fsr_trace_pattern.output
    params:
        figure_width=3,
        figure_height=3,
        alpha=0.05
    version:
        v('scripts/fsr/plot_dai_fs_coefficients_k.R')
    shell:
        'Rscript scripts/fsr/plot_dai_fs_coefficients_k.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height} --alpha {params.alpha}'



rule nmf_discovery_outcomes_fsr_coefficients_k:
    input:
        expand(rules.nmf_discovery_outcomes_fsr_coefficient_k_pattern.output, analysis=ANALYSES, visit=VISITS)



# Targets.

rule nmf_discovery_outcomes_fsr_tables:
    input:
        rules.discovery_outcomes_fsr_data.input,
        rules.discovery_outcomes_fsr_traces.input



rule nmf_discovery_outcomes_fsr_figures:
    input:
        rules.nmf_discovery_outcomes_fsr_n_coefficients.input,
        rules.nmf_discovery_outcomes_fsr_coefficients.input,
        rules.nmf_discovery_outcomes_fsr_coefficients_k.input



rule nmf_discovery_outcomes_fsr:
    input:
        rules.nmf_discovery_outcomes_fsr_tables.input,
        rules.nmf_discovery_outcomes_fsr_figures.input
