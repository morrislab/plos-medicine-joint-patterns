"""
Calculates variance explained in the discovery cohort.
"""

DATA = 'inputs/variance_explained/discovery/joints.csv'
SCORES = 'inputs/variance_explained/discovery/scores/{level}.csv'
CLUSTERS = 'inputs/variance_explained/discovery/clusters.csv'
DIAGNOSES = 'inputs/variance_explained/discovery/diagnoses.csv'

LEVELS = ['l1', 'l2']



# Link inputs.

rule variance_explained_discovery_inputs_joints:
    output: DATA
    input: 'outputs/data/discovery/joints.csv'
    shell: LN



rule variance_explained_discovery_inputs_scores_pattern:
    output: SCORES
    input: 'outputs/nmf/discovery/{level}/model/scores.csv'
    shell: LN



rule variance_explained_discovery_inputs_scores:
    input:
        expand(rules.variance_explained_discovery_inputs_scores_pattern.output, level=LEVELS),



rule variance_explained_discovery_inputs_clusters:
    output: CLUSTERS
    input: 'outputs/clusters/discovery.csv'
    shell: LN



rule variance_explained_discovery_inputs_diagnoses:
    output: DIAGNOSES
    input: 'outputs/diagnoses/roots/discovery.csv'
    shell: LN



rule variance_explained_discovery_inputs:
    input:
        DATA,
        rules.variance_explained_discovery_inputs_scores.output,
        CLUSTERS,
        DIAGNOSES,



# Analyses.

rule variance_explained_discovery_scores_pattern:
    output: 'tables/variance_explained/discovery/{level}/scores.csv'
    log: 'tables/variance_explained/discovery/{level}/scores.csv'
    benchmark: 'tables/variance_explained/discovery/{level}/scores.txt'
    input:
        data=DATA,
        scores=SCORES,
    version: v('scripts/nmf/get_variance_explained_scores.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_scores.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



rule variance_explained_discovery_scores:
    input:
        expand(rules.variance_explained_discovery_scores_pattern.output, level=LEVELS),



rule variance_explained_discovery_clusters:
    output: 'tables/variance_explained/discovery/clusters.csv'
    log: 'tables/variance_explained/discovery/clusters.log'
    benchmark: 'tables/variance_explained/discovery/clusters.txt'
    input:
        data=DATA,
        clusters=CLUSTERS,
    version: v('scripts/nmf/get_variance_explained_clusters.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_clusters.R --predictor-input {input.clusters} --response-input {input.data} --output {output}' + LOG



rule variance_explained_discovery_ilar:
    output: 'tables/variance_explained/discovery/ilar.csv'
    log: 'tables/variance_explained/discovery/ilar.log'
    benchmark: 'tables/variance_explained/discovery/ilar.txt'
    input:
        data=DATA,
        scores=DIAGNOSES,
    version: v('scripts/nmf/get_variance_explained_ilar.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_ilar.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



# Targets.

rule variance_explained_discovery_tables:
    input:
        rules.variance_explained_discovery_scores.input,
        rules.variance_explained_discovery_clusters.output,
        rules.variance_explained_discovery_ilar.output



rule variance_explained_discovery_parameters:
    input:



rule variance_explained_discovery_figures:
    input:



rule variance_explained_discovery:
    input:
        rules.variance_explained_discovery_tables.input,
        rules.variance_explained_discovery_parameters.input,
        rules.variance_explained_discovery_figures.input,
