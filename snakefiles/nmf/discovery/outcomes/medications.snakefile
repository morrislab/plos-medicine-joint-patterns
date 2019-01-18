# Medications at later time points.

ANALYSES = ['base', 'localized']

LOCALIZATIONS = ['localized', 'diffuse']



# Summary data, including data for localized/diffuse involvements separately.

rule discovery_outcomes_medication_summary_base:
    output:
        'tables/discovery/nmf/outcomes/medications/summaries/base.csv'
    input:
        clusters=rules.clusters_discovery_full.output,
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        medications=rules.data_discovery_medications.output,
        joint_injections=rules.data_discovery_joint_injections.output
    params:
        visits=[2, 3]
    version:
        v('scripts/outcomes/summarize_medications.py')
    run:
        shell('python scripts/outcomes/summarize_medications.py --medication-input {{input.medications}} --joint-injection-input {{input.joint_injections}} --cluster-input {{input.clusters}} --diagnosis-input {{input.diagnoses}} --output {{output}} {}'.format(' '.join('--visit {}'.format(visit) for visit in params.visits)))



rule discovery_outcomes_medication_localized_summary_preformatted:
    output:
        'tables/discovery/nmf/outcomes/medications/summaries/localized_unformatted.csv'
    input:
        clusters=rules.clusters_discovery_localized_full.output,
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        medications=rules.data_discovery_medications.output,
        joint_injections=rules.data_discovery_joint_injections.output
    params:
        visits=[2, 3]
    version:
        v('scripts/outcomes/summarize_medications.py')
    run:
        shell('python scripts/outcomes/summarize_medications.py --medication-input {{input.medications}} --joint-injection-input {{input.joint_injections}} --cluster-input {{input.clusters}} --diagnosis-input {{input.diagnoses}} --output {{output}} {}'.format(' '.join('--visit {}'.format(visit) for visit in params.visits)))



# Reformat the classification types for the localized analysis.

rule discovery_outcomes_medication_summary_localized:
    output:
        'tables/discovery/nmf/outcomes/medications/summaries/localized.csv'
    input:
        rules.discovery_outcomes_medication_localized_summary_preformatted.output
    version:
        v('scripts/outcomes/reformat_medication_class_types.py')
    shell:
        'python scripts/outcomes/reformat_medication_class_types.py --input {input} --output {output}'



rule discovery_outcomes_medication_summaries:
    input:
        rules.discovery_outcomes_medication_summary_base.output,
        rules.discovery_outcomes_medication_localized_summary_preformatted.output,
        rules.discovery_outcomes_medication_summary_localized.output



# Figures.

rule discovery_outcomes_medication_figure_base:
    output:
        'figures/discovery/nmf/outcomes/medications/base.pdf'
    input:
        rules.discovery_outcomes_medication_summary_base.output
    params:
        figure_width=4.5,
        figure_height=6
    version:
        v('scripts/outcomes/plot_medications.R')
    shell:
        'Rscript scripts/outcomes/plot_medications.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



rule discovery_outcomes_medication_figure_localized:
    output:
        'figures/discovery/nmf/outcomes/medications/localized.pdf'
    input:
        rules.discovery_outcomes_medication_summary_localized.output
    params:
        figure_width=5,
        figure_height=6
    version:
        v('scripts/outcomes/plot_medications.R')
    shell:
        'Rscript scripts/outcomes/plot_medications.R --input {input} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height}'



# Statistics.

rule discovery_outcomes_medication_stats_pattern:
    output:
        'tables/discovery/nmf/outcomes/medications/stats/{analysis}.csv'
    input:
        'tables/discovery/nmf/outcomes/medications/summaries/{analysis}.csv'
    params:
        iterations=20000
    version:
        v('scripts/outcomes/do_medication_stats.R')
    shell:
        'Rscript scripts/outcomes/do_medication_stats.R --input {input} --output {output} --iterations {params.iterations}'



rule discovery_outcomes_medication_stats:
    input:
        expand(rules.discovery_outcomes_medication_stats_pattern.output, analysis=ANALYSES)



# Targets.

rule discovery_outcomes_medication_tables:
    input:
        rules.discovery_outcomes_medication_summaries.input,
        rules.discovery_outcomes_medication_stats.input



rule discovery_outcomes_medication_figures:
    input:
        rules.discovery_outcomes_medication_figure_base.output,
        rules.discovery_outcomes_medication_figure_localized.output



rule discovery_outcomes_medications:
    input:
        rules.discovery_outcomes_medication_tables.input,
        rules.discovery_outcomes_medication_figures.input
