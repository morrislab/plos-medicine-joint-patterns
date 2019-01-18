"""
Reconstructions of the original data for the validation cohort.
"""

DATA = 'inputs/reconstructions/validation/joints.csv'
BASIS = 'inputs/reconstructions/validation/basis/{level}.csv'
BASIS_L1 = expand(BASIS, level='l1')
BASIS_L2 = expand(BASIS, level='l2')
SCORES = 'inputs/reconstructions/validation/scores/{level}.csv'
SCORES_L1 = expand(SCORES, level='l1')
SCORES_L2 = expand(SCORES, level='l2')
SCALING_PARAMETERS = 'inputs/reconstructions/validation/scaling_parameters/{level}.csv'
SCALING_PARAMETERS_L1 = expand(SCALING_PARAMETERS, level='l1')
SCALING_PARAMETERS_L2 = expand(SCALING_PARAMETERS, level='l2')
CLUSTERS = 'inputs/reconstructions/validation/clusters.csv'

LEVELS = ['l1', 'l2']



# Link inputs.

rule reconstructions_validation_inputs_joints:
    output: DATA
    input: 'outputs/data/validation/joints.csv'
    shell: LN



rule reconstructions_validation_inputs_basis_pattern:
    output: BASIS
    input: 'outputs/nmf/validation/{level}/model/basis.csv'
    shell: LN



rule reconstructions_validation_inputs_scores_pattern:
    output: SCORES
    input: 'outputs/nmf/validation/{level}/model/scores.csv'
    shell: LN



rule reconstructions_validation_inputs_scaling_parameters_pattern:
    output: SCALING_PARAMETERS
    input: 'outputs/nmf/validation/{level}/scaled/parameters.csv'
    shell: LN



rule reconstructions_validation_inputs_clusters:
    output: CLUSTERS
    input: 'outputs/clusters/validation.csv'
    shell: LN



rule reconstructions_validation_inputs:
    input:
        rules.reconstructions_validation_inputs_joints.output,
        expand(rules.reconstructions_validation_inputs_basis_pattern.output, level=LEVELS),
        expand(rules.reconstructions_validation_inputs_scores_pattern.output, level=LEVELS),
        expand(rules.reconstructions_validation_inputs_scaling_parameters_pattern.output, level=LEVELS),
        rules.reconstructions_validation_inputs_clusters.output,



# Starting at L2.

rule reconstructions_validation_factors_scaled_l2_l1:
    output: 'tables/reconstructions/validation/factors/scaled/l2_l1.csv'
    log: 'tables/reconstructions/validation/factors/scaled/l2_l1.log'
    benchmark: 'tables/reconstructions/validation/factors/scaled/l2_l1.txt'
    input:
        basis=BASIS_L2,
        coefficients=SCORES_L2,
    version: v('scripts/reconstructions/reconstruct_from_factors.py')
    shell:
        'python scripts/reconstructions/reconstruct_from_factors.py --basis-input {input.basis} --coefficient-input {input.coefficients} --output {output}' + LOG



rule reconstructions_validation_factors_unscaled_l2_l1:
    output: 'tables/reconstructions/validation/factors/unscaled/l2_l1.csv'
    log: 'tables/reconstructions/validation/factors/unscaled/l2_l1.log'
    benchmark: 'tables/reconstructions/validation/factors/unscaled/l2_l1.txt'
    input:
        data=rules.reconstructions_validation_factors_scaled_l2_l1.output,
        scaling_parameters=SCALING_PARAMETERS_L2,
    version: v('scripts/reconstructions/unscale.py')
    shell:
        'python scripts/reconstructions/unscale.py --data-input {input.data} --scaling-parameter-input {input.scaling_parameters} --output {output}' + LOG



rule reconstructions_validation_factors_scaled_l2_l1_l0:
    output: 'tables/reconstructions/validation/factors/scaled/l2_l1_l0.csv'
    log: 'tables/reconstructions/validation/factors/scaled/l2_l1_l0.log'
    benchmark: 'tables/reconstructions/validation/factors/scaled/l2_l1_l0.txt'
    input:
        basis=BASIS_L1,
        coefficients=rules.reconstructions_validation_factors_unscaled_l2_l1.output
    version: v('scripts/reconstructions/reconstruct_from_factors.py')
    shell:
        'python scripts/reconstructions/reconstruct_from_factors.py --basis-input {input.basis} --coefficient-input {input.coefficients} --output {output}' + LOG



rule reconstructions_validation_factors_unscaled_l2_l1_l0:
    output: 'tables/reconstructions/validation/factors/unscaled/l2_l1_l0.csv'
    log: 'tables/reconstructions/validation/factors/unscaled/l2_l1_l0.log'
    benchmark: 'tables/reconstructions/validation/factors/unscaled/l2_l1_l0.txt'
    input:
        data=rules.reconstructions_validation_factors_scaled_l2_l1_l0.output,
        scaling_parameters=SCALING_PARAMETERS_L1,
    version:
        v('scripts/reconstructions/unscale.py')
    shell:
        'python scripts/reconstructions/unscale.py --data-input {input.data} --scaling-parameter-input {input.scaling_parameters} --output {output}' + LOG



## Starting at L1.

rule reconstructions_validation_factors_scaled_l1_l0:
    output: 'tables/reconstructions/validation/factors/scaled/l1_l0.csv'
    log: 'tables/reconstructions/validation/factors/scaled/l1_l0.log'
    benchmark: 'tables/reconstructions/validation/factors/scaled/l1_l0.txt'
    input:
        basis=BASIS_L1,
        coefficients=SCORES_L1,
    version: v('scripts/reconstructions/reconstruct_from_factors.py')
    shell:
        'python scripts/reconstructions/reconstruct_from_factors.py --basis-input {input.basis} --coefficient-input {input.coefficients} --output {output}' + LOG



rule reconstructions_validation_factors_unscaled_l1_l0:
    output: 'tables/reconstructions/validation/factors/unscaled/l1_l0.csv'
    log: 'tables/reconstructions/validation/factors/unscaled/l1_l0.log'
    benchmark: 'tables/reconstructions/validation/factors/unscaled/l1_l0.txt'
    input:
        data=rules.reconstructions_validation_factors_scaled_l1_l0.output,
        scaling_parameters=SCALING_PARAMETERS_L1,
    version: v('scripts/reconstructions/unscale.py')
    shell:
        'python scripts/reconstructions/unscale.py --data-input {input.data} --scaling-parameter-input {input.scaling_parameters} --output {output}' + LOG



rule reconstructions_validation_factors_scaled:
    input:
        expand('tables/reconstructions/validation/factors/{x}/{y}.csv', x=['scaled', 'unscaled'], y=['l2_l1', 'l2_l1_l0', 'l1_l0'])



# Reconstructions from cluster assignments.

rule reconstructions_validation_clusters:
    output: 'tables/reconstructions/validation/clusters.csv'
    log: 'tables/reconstructions/validation/clusters.log'
    benchmark: 'tables/reconstructions/validation/clusters.txt'
    input:
        data=DATA,
        clusters=CLUSTERS,
    version: v('scripts/reconstructions/reconstruct_from_clusters.py')
    shell:
        'python scripts/reconstructions/reconstruct_from_clusters.py --data-input {input.data} --cluster-input {input.clusters} --output {output}' + LOG



# Link outputs.

rule reconstructions_validation_outputs_pattern:
    output: 'outputs/reconstructions/validation/{y}.csv'
    input: 'tables/reconstructions/validation/factors/unscaled/{y}.csv'
    shell: LN



rule reconstructions_validation_outputs_clusters:
    output: 'outputs/reconstructions/validation/clusters.csv'
    input: rules.reconstructions_validation_clusters.output
    shell: LN



rule reconstructions_validation_outputs:
    input:
        expand(rules.reconstructions_validation_outputs_pattern.output, y=['clusters', 'l2_l1', 'l2_l1_l0', 'l1_l0'])



# Targets.

rule reconstructions_validation_tables:
    input:
        rules.reconstructions_validation_factors_scaled.input,
        rules.reconstructions_validation_clusters.output,



rule reconstructions_validation_parameters:
    input:



rule reconstructions_validation_figures:
    input:



rule reconstructions_validation:
    input:
        rules.reconstructions_validation_inputs.input,
        rules.reconstructions_validation_tables.input,
        rules.reconstructions_validation_parameters.input,
        rules.reconstructions_validation_figures.input,
        rules.reconstructions_validation_outputs.input,
