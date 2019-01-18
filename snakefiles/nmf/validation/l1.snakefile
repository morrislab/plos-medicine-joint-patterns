"""
Conducts the first level of multilayer NMF.
"""

PARAMS_K = config.nmf.bicv.k.validation.l1
PARAMS_ALPHA = config.nmf.bicv.alpha.validation.l1

K_ITERATION_RANGE = list(range(1, PARAMS_K.batches + 1))
ALPHA_ITERATION_RANGE = list(range(1, PARAMS_ALPHA.batches + 1))
ALPHA_RANGE = PARAMS_ALPHA.alpha_range

INPUT = 'inputs/nmf/validation/l1/data/joints.csv'
SEED_K = 'tables/nmf/validation/l1/bicv/k/seeds/{iteration}.txt'
SEED_ALPHA = 'tables/nmf/validation/l1/bicv/alpha/seeds/{iteration}.txt'

PARAMETER_K = 'parameters/nmf/k/validation/l1.txt'
PARAMETER_ALPHA = 'parameters/nmf/alpha/validation/l1.txt'



# Link inputs.

rule nmf_validation_l1_inputs_data:
    output: INPUT
    input: 'outputs/data/validation/joints.csv'
    shell: LN



rule nmf_validation_l1_inputs:
    input:
        rules.nmf_validation_l1_inputs_data.output,



# Scale the data.

rule nmf_validation_l1_scaled:
    output:
        data='tables/nmf/validation/l1/scaled/data.csv',
        parameters='tables/nmf/validation/l1/scaled/parameters.csv',
        flag=touch('tables/nmf/validation/l1/scaled/scaled.done'),
    input: INPUT
    version: v('scripts/general/scale_data.py')
    shell:
        'python scripts/general/scale_data.py --input {input} --output {output.data} --parameter-output {output.parameters} --scale' + LOG



# Cross-validation to find the rank.
# NOTE: Figures and parameters are defined as more general rules.

rule nmf_validation_l1_bicv_k_seeds:
    output: expand('tables/nmf/validation/l1/bicv/k/seeds/{iteration}.txt', iteration=K_ITERATION_RANGE)
    log: 'tables/nmf/validation/l1/bicv/k/seeds/seeds.log'
    benchmark: 'tables/nmf/validation/l1/bicv/k/seeds/seeds.txt'
    params:
        prefix='tables/nmf/validation/l1/bicv/k/seeds/',
        each=PARAMS_K.each,
        jobs=PARAMS_K.batches,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --iterations-per-job {params.each} --output-prefix {params.prefix} --jobs {params.jobs}' + LOG



rule nmf_validation_l1_bicv_q2_samples_k_pattern:
    output: 'tables/nmf/validation/l1/bicv/q2/samples/k/{iteration}.feather'
    log: 'tables/nmf/validation/l1/bicv/q2/samples/k/{iteration}.log'
    benchmark: 'tables/nmf/validation/l1/bicv/q2/samples/k/{iteration}.txt'
    input:
        rules.nmf_validation_l1_scaled.output.flag,
        data=rules.nmf_validation_l1_scaled.output.data,
        seeds=SEED_K,
    params:
        folds=PARAMS_K.folds,
        k_max=PARAMS_K.k_max,
    version: v('scripts/nmf/cv_nmf_bicv_alpha_seedlist.py')
    shell:
        'python scripts/nmf/cv_nmf_bicv_alpha_seedlist.py --input {input.data} --seedlist {input.seeds} --folds {params.folds} --output {output} --init nndsvd --l1-ratio 1 --alpha 0 --k `seq 2 {params.k_max}` --log {log} --cores 1' + LOG



rule nmf_validation_l1_bicv_q2_combined_k_pattern:
    output: 'tables/nmf/validation/l1/bicv/q2/combined/k.feather'
    log: 'tables/nmf/validation/l1/bicv/q2/combined/k.log'
    benchmark: 'tables/nmf/validation/l1/bicv/q2/combined/k.txt'
    input: expand(rules.nmf_validation_l1_bicv_q2_samples_k_pattern.output, iteration=K_ITERATION_RANGE)
    version: v('scripts/nmf/concatenate_q2.py')
    shell:
        'python scripts/nmf/concatenate_q2.py --inputs {input} --output {output}' + LOG



rule nmf_validation_l1_k_parameter:
    input:
        PARAMETER_K,



# Cross-validation to find alpha.

rule nmf_validation_l1_bicv_alpha_seeds:
    output: expand(SEED_ALPHA, iteration=ALPHA_ITERATION_RANGE)
    log: 'tables/nmf/validation/l1/bicv/alpha/seeds/seeds.log'
    benchmark: 'tables/nmf/validation/l1/bicv/alpha/seeds/seeds.txt'
    params:
        prefix='tables/nmf/validation/l1/bicv/alpha/seeds/',
        each=PARAMS_ALPHA.each,
        jobs=PARAMS_ALPHA.batches,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --iterations-per-job {params.each} --output-prefix {params.prefix} --jobs {params.jobs}' + LOG



rule nmf_validation_l1_bicv_q2_samples_alpha_pattern:
    output: 'tables/nmf/validation/l1/bicv/q2/samples/alpha/{iteration}/{alpha}.feather'
    log: 'tables/nmf/validation/l1/bicv/q2/samples/alpha/{iteration}/{alpha}.log'
    benchmark: 'tables/nmf/validation/l1/bicv/q2/samples/alpha/{iteration}/{alpha}.txt'
    input:
        rules.nmf_validation_l1_scaled.output.flag,
        data=rules.nmf_validation_l1_scaled.output.data,
        seeds=SEED_ALPHA,
        k=rules.nmf_validation_l1_k_parameter.input,
    params:
        folds=PARAMS_ALPHA.folds,
    shell:
        'python scripts/nmf/cv_nmf_bicv_alpha_seedlist.py --input {input.data} --seedlist {input.seeds} --folds {params.folds} --output {output} --init nndsvd --l1-ratio 1 --alpha {wildcards.alpha} --k `cat {input.k}` --log {log} --cores 1' + LOG



rule nmf_validation_l1_bicv_q2_combined_alpha_pattern:
    output: 'tables/nmf/validation/l1/bicv/q2/combined/alpha.feather'
    log: 'tables/nmf/validation/l1/bicv/q2/combined/alpha.log'
    benchmark: 'tables/nmf/validation/l1/bicv/q2/combined/alpha.txt'
    input:
        expand(rules.nmf_validation_l1_bicv_q2_samples_alpha_pattern.output, alpha=ALPHA_RANGE, iteration=ALPHA_ITERATION_RANGE)
    version: v('scripts/nmf/concatenate_q2.py')
    shell:
        'python scripts/nmf/concatenate_q2.py --inputs {input} --output {output}' + LOG



rule nmf_validation_l1_alpha_parameter:
    input:
        PARAMETER_ALPHA,



# Compile seeds together.

rule nmf_validation_l1_bicv_seeds:
    input:
        rules.nmf_validation_l1_bicv_k_seeds.output,
        rules.nmf_validation_l1_bicv_alpha_seeds.output,



# Summaries.

rule nmf_validation_l1_bicv_summaries:
    input:
        expand('tables/nmf/validation/l1/bicv/{parameter}/summaries.csv', parameter=PARAMETERS),



# NMF.

rule nmf_validation_l1_nmf:
    input:
        expand('tables/nmf/validation/l1/nmf/{file}', file=MODEL_FILES),



rule nmf_validation_l1_joint_order:
    output: 'tables/nmf/validation/l1/site_order.txt'
    input: 'data/site_order.txt'
    shell: LN



rule nmf_validation_l1_reordered:
    input:
        expand('tables/nmf/validation/l1/reordered/{file}', file=MODEL_FILES),



rule nmf_validation_l1_sparsified:
    input:
        expand('tables/nmf/validation/l1/sparsified/{file}', file=MODEL_FILES),
        'tables/nmf/validation/l1/sparsified/stats.csv',



# Figures.

rule nmf_validation_l1_bicv_k_fig:
    input:
        'figures/nmf/validation/l1/bicv/q2/k.pdf',



rule nmf_validation_l1_bicv_alpha_fig:
    input:
        'figures/nmf/validation/l1/bicv/q2/alpha.pdf',



rule nmf_validation_l1_reordered_fig:
    input:
        'figures/nmf/validation/l1/reordered/basis.pdf',



rule nmf_validation_l1_sparsified_fig:
    input:
        'figures/nmf/validation/l1/sparsified/correlations.pdf',
        'figures/nmf/validation/l1/sparsified/basis.pdf',



# Link outputs.

rule nmf_validation_l1_outputs_scaled_pattern:
    output: 'outputs/nmf/validation/l1/scaled/{file}'
    input:
        'tables/nmf/validation/l1/scaled/scaled.done',
        input='tables/nmf/validation/l1/scaled/{file}',
    shell: LN_ALT



rule nmf_validation_l1_outputs_model_pattern:
    output: 'outputs/nmf/validation/l1/model/{file}'
    input:
        'tables/nmf/validation/l1/sparsified/model.done',
        input='tables/nmf/validation/l1/sparsified/{file}',
    shell: LN_ALT



rule nmf_validation_l1_outputs:
    input:
        expand(rules.nmf_validation_l1_outputs_scaled_pattern.output, file=SCALED_FILES),
        expand(rules.nmf_validation_l1_outputs_model_pattern.output, file=MODEL_FILES),



# Targets.

rule nmf_validation_l1_tables:
    input:
        rules.nmf_validation_l1_bicv_seeds.input,
        rules.nmf_validation_l1_reordered.input,
        rules.nmf_validation_l1_sparsified.input,
        rules.nmf_validation_l1_bicv_summaries.input



rule nmf_validation_l1_parameters:
    input:
        rules.nmf_validation_l1_k_parameter.input,
        rules.nmf_validation_l1_alpha_parameter.input,



rule nmf_validation_l1_figures:
    input:
        rules.nmf_validation_l1_bicv_k_fig.input,
        rules.nmf_validation_l1_bicv_alpha_fig.input,
        rules.nmf_validation_l1_reordered_fig.input,
        rules.nmf_validation_l1_sparsified_fig.input,



rule nmf_validation_l1:
    input:
        rules.nmf_validation_l1_inputs.input,
        rules.nmf_validation_l1_tables.input,
        rules.nmf_validation_l1_parameters.input,
        rules.nmf_validation_l1_figures.input
