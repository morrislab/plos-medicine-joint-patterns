"""
Generates Circos figures.
"""

CLUSTER_INPUT = 'inputs/circos/clusters/{cohort}.csv'
DIAGNOSIS_INPUT = 'inputs/circos/diagnoses/{cohort}.csv'
SCORE_INPUT = 'inputs/circos/scores/{cohort}.csv'
DIAGNOSIS_MAP = 'data/circos/diagnosis_mapping.yaml'

LEVEL = config.circos.level



# Link inputs.

rule circos_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/{cohort}.csv'
    shell: LN



rule circos_inputs_diagnoses_pattern:
    output: DIAGNOSIS_INPUT
    input: 'outputs/diagnoses/{cohort}.csv'
    shell: LN



rule circos_inputs_scores_pattern:
    output: SCORE_INPUT
    input: expand('outputs/nmf/{{cohort}}/{level}/model/scores.csv', level=LEVEL),
    shell: LN



rule circos_inputs:
    input:
        expand(rules.circos_inputs_clusters_pattern.output, cohort='discovery'),
        expand(rules.circos_inputs_diagnoses_pattern.output, cohort='discovery'),
        expand(rules.circos_inputs_scores_pattern.output, cohort='discovery'),



# Generate files.

rule circos_files_pattern:
    output:
        conf='figures/circos/{cohort}/circos.conf',
        colours='figures/circos/{cohort}/colours.conf',
        heatmaps='figures/circos/{cohort}/heatmaps.conf',
        karyotype='figures/circos/{cohort}/karyotype.txt',
        memberships='figures/circos/{cohort}/memberships.txt',
        flag=touch('figures/circos/{cohort}/circos.done'),
    log: 'figures/circos/{cohort}/circos.log'
    benchmark: 'figures/circos/{cohort}/circos.txt'
    input:
        clusters=CLUSTER_INPUT,
        diagnoses=DIAGNOSIS_INPUT,
        scores=SCORE_INPUT,
        diagnosis_map=DIAGNOSIS_MAP,
    params:
        base_dir='figures/circos/{cohort}'
    version: v('scripts/circos/make_circos.py')
    shell:
        'python scripts/circos/make_circos.py --clusters {input.clusters} --diagnoses {input.diagnoses} --scores {input.scores} --diagnosis-map {input.diagnosis_map} --base-dir {params.base_dir}' + LOG



rule circos_files:
    input:
        expand(rules.circos_files_pattern.output, cohort='discovery'),



# Run Circos.

rule circos_fig_pattern:
    output:
        svg='figures/circos/{cohort}/circos.svg',
        png='figures/circos/{cohort}/circos.png',
        flag=touch('figures/circos/{cohort}/circos_fig.done'),
    log: 'figures/circos/{cohort}/circos_fig.log'
    benchmark: 'figures/circos/{cohort}/circos_fig.txt'
    input: rules.circos_files_pattern.output
    shell:
        'cd figures/circos/{wildcards.cohort} && circos'



rule circos_fig:
    input:
        expand(rules.circos_fig_pattern.output, cohort='discovery'),



# Targets.

rule circos_tables:
    input:
        rules.circos_files.input,



rule circos_parameters:
    input:



rule circos_figures:
    input:
        # rules.circos_fig.input,



rule circos:
    input:
        rules.circos_inputs.input,
        rules.circos_tables.input,
        rules.circos_parameters.input,
        rules.circos_figures.input,
