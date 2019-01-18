# Age and time in the discovery cohort.

rule outcomes_age_time_discovery_figure:
    input:
        data=rules.data_discovery_basics.output,
        clusters=rules.clusters_discovery_full.output,
        diagnoses=rules.diagnoses_discovery_filtered.output
    output:
        'figures/outcomes/age_time/discovery.pdf'
    params:
        figure_width=4.75,
        figure_height=4.75
    version:
        v('scripts/outcomes/plot_age_time.R')
    shell:
        'Rscript scripts/outcomes/plot_age_time.R --data-input {input.data} --classification-input {input.clusters} --diagnosis-input {input.diagnoses} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



rule outcomes_age_time_discovery_stats:
    input:
        data=rules.data_discovery_basics.output,
        clusters=rules.clusters_discovery_full.output,
        diagnoses=rules.diagnoses_discovery_filtered.output
    output:
        'tables/outcomes/age_time/stats/discovery.csv'
    version:
        v('scripts/outcomes/do_age_time_stats.R')
    shell:
        'Rscript scripts/outcomes/do_age_time_stats.R --data-input {input.data} --classification-input {input.clusters} --diagnosis-input {input.diagnoses} --output {output}'



# Targets.

rule outcomes_age_time_discovery_tables:
    input:
        rules.outcomes_age_time_discovery_stats.output



rule outcomes_age_time_discovery_figures:
    input:
        rules.outcomes_age_time_discovery_figure.output



rule outcomes_age_time_discovery:
    input:
        rules.outcomes_age_time_discovery_tables.input,
        rules.outcomes_age_time_discovery_figures.input
