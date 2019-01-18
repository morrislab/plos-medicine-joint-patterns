"""
Calculates variance explained in the validation cohort.
"""

DATA = 'inputs/variance_explained/validation/joints.csv'
SCORES = 'inputs/variance_explained/validation/scores/{level}.csv'
CLUSTERS = 'inputs/variance_explained/validation/clusters.csv'
DIAGNOSES = 'inputs/variance_explained/validation/diagnoses.csv'

LEVELS = ['l1', 'l2']



# Link inputs.

rule variance_explained_validation_inputs_joints:
    output: DATA
    input: 'outputs/data/validation/joints.csv'
    shell: LN



rule variance_explained_validation_inputs_scores_pattern:
    output: SCORES
    input: 'outputs/nmf/validation/{level}/model/scores.csv'
    shell: LN



rule variance_explained_validation_inputs_scores:
    input:
        expand(rules.variance_explained_validation_inputs_scores_pattern.output, level=LEVELS),



rule variance_explained_validation_inputs_clusters:
    output: CLUSTERS
    input: 'outputs/clusters/validation.csv'
    shell: LN



rule variance_explained_validation_inputs_diagnoses:
    output: DIAGNOSES
    input: 'outputs/diagnoses/roots/validation.csv'
    shell: LN



rule variance_explained_validation_inputs:
    input:
        DATA,
        rules.variance_explained_validation_inputs_scores.output,
        CLUSTERS,
        DIAGNOSES,



# Variance explained for the validation cohort.

rule variance_explained_validation_scores_pattern:
    output: 'tables/variance_explained/validation/{level}/scores.csv'
    log: 'tables/variance_explained/validation/{level}/scores.log'
    benchmark: 'tables/variance_explained/validation/{level}/scores.txt'
    input:
        data=DATA,
        scores=SCORES,
    version: v('scripts/nmf/get_variance_explained_scores.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_scores.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



rule variance_explained_validation_scores:
    input:
        expand(rules.variance_explained_validation_scores_pattern.output, level=LEVELS),



rule variance_explained_validation_clusters:
    output: 'tables/variance_explained/validation/clusters.csv'
    log: 'tables/variance_explained/validation/clusters.log'
    benchmark: 'tables/variance_explained/validation/clusters.txt'
    input:
        data=DATA,
        scores=CLUSTERS,
    version: v('scripts/nmf/get_variance_explained_clusters.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_clusters.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



rule variance_explained_validation_ilar:
    output: 'tables/variance_explained/validation/ilar.csv'
    log: 'tables/variance_explained/validation/ilar.log'
    benchmark: 'tables/variance_explained/validation/ilar.txt'
    input:
        data=DATA,
        scores=DIAGNOSES,
    version: v('scripts/nmf/get_variance_explained_ilar.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_ilar.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



# Targets.

rule variance_explained_validation_tables:
    input:
        rules.variance_explained_validation_scores.input,
        rules.variance_explained_validation_clusters.output,
        rules.variance_explained_validation_ilar.output,



rule variance_explained_validation_parameters:
    input:



rule variance_explained_validation_figures:
    input:



rule variance_explained_validation:
    input:
        rules.variance_explained_validation_tables.input,
        rules.variance_explained_validation_parameters.input,
        rules.variance_explained_validation_figures.input
