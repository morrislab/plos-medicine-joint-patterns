# FSR using cluster assignments.

rule nmf_discovery_outcomes_fsr_cluster_traces:
    output:
        'tables/discovery/nmf/outcomes/fsr/clusters/traces.rda'
    input:
        dai_scores=rules.data_discovery_dai_projections.output,
        medications=rules.data_discovery_medications.output,
        clusters=rules.clusters_discovery_full.output,
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        age_time=rules.data_discovery_basics.output
    params:
        ignore='nsaid_status',
        visits=[2, 3]
    version:
        v('scripts/fsr/predict_dai_fs_clusters.R')
    shell:
        'Rscript scripts/fsr/predict_dai_fs_clusters.R --projection-input {input.dai_scores} --medication-input {input.medications} --cluster-input {input.clusters} --diagnosis-input {input.diagnoses} --age-time-input {input.age_time} --output {output} --ignore {params.ignore} --visits {params.visits}'



rule nmf_discovery_outcomes_fsr_cluster_n_coefficients_figure:
    output:
        'figures/discovery/nmf/outcomes/fsr/clusters/n_coefficients.pdf'
    input:
        rules.nmf_discovery_outcomes_fsr_cluster_traces.output
    params:
        figure_width=3,
        figure_height=3
    version:
        v('scripts/fsr/plot_num_coefficients.R')
    shell:
        'Rscript scripts/fsr/plot_num_coefficients.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



rule nmf_discovery_outcomes_fsr_cluster_coefficient_figure:
    output:
        'figures/discovery/nmf/outcomes/fsr/clusters/coefficients.pdf'
    input:
        rules.nmf_discovery_outcomes_fsr_cluster_traces.output
    params:
        figure_width=3,
        figure_height=3,
        alpha=0.05
    version:
        v('scripts/fsr/plot_dai_fs_coefficients.R')
    shell:
        'Rscript scripts/fsr/plot_dai_fs_coefficients.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height} --alpha {params.alpha}'



# Targets.

rule nmf_discovery_outcomes_fsr_cluster_tables:
    input:
        rules.nmf_discovery_outcomes_fsr_cluster_traces.output



rule nmf_discovery_outcomes_fsr_cluster_figures:
    input:
        rules.nmf_discovery_outcomes_fsr_cluster_n_coefficients_figure.output,
        rules.nmf_discovery_outcomes_fsr_cluster_coefficient_figure.output



rule nmf_discovery_outcomes_fsr_clusters:
    input:
        rules.nmf_discovery_outcomes_fsr_cluster_tables.input,
        rules.nmf_discovery_outcomes_fsr_cluster_figures.input
