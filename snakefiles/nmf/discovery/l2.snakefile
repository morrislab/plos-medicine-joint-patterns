"""
Conducts the second level of multilayer NMF.
"""

PARAMS_K = config.nmf.bicv.k.discovery.l2
PARAMS_ALPHA = config.nmf.bicv.alpha.discovery.l2

K_ITERATION_RANGE = list(range(1, PARAMS_K.batches + 1))
ALPHA_ITERATION_RANGE = list(range(1, PARAMS_ALPHA.batches + 1))
ALPHA_RANGE = PARAMS_ALPHA.alpha_range

INPUT = 'inputs/nmf/discovery/l2/data/scores.csv'
SEED_K = 'tables/nmf/discovery/l2/bicv/k/seeds/{iteration}.txt'
SEED_ALPHA = 'tables/nmf/discovery/l2/bicv/alpha/seeds/{iteration}.txt'

PARAMETER_K = 'parameters/nmf/k/discovery/l2.txt'
PARAMETER_ALPHA = 'parameters/nmf/alpha/discovery/l2.txt'



# Link inputs.

rule nmf_discovery_l2_inputs_data:
    output: INPUT
    input: 'outputs/nmf/discovery/l1/model/scores.csv'
    shell: LN



rule nmf_discovery_l2_inputs:
    input:
        rules.nmf_discovery_l2_inputs_data.output,



# Scale the data.

rule nmf_discovery_l2_scaled:
    output:
        data='tables/nmf/discovery/l2/scaled/data.csv',
        parameters='tables/nmf/discovery/l2/scaled/parameters.csv',
        flag=touch('tables/nmf/discovery/l2/scaled/scaled.done'),
    input: INPUT
    version: v('scripts/general/scale_data.py')
    shell:
        'python scripts/general/scale_data.py --input {input} --output {output.data} --parameter-output {output.parameters} --scale' + LOG



# Cross-discovery to find the rank.
# NOTE: Figures and parameters are defined as more general rules.

rule nmf_discovery_l2_bicv_k_seeds:
    output: expand('tables/nmf/discovery/l2/bicv/k/seeds/{iteration}.txt', iteration=K_ITERATION_RANGE)
    log: 'tables/nmf/discovery/l2/bicv/k/seeds/seeds.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/k/seeds/seeds.txt'
    params:
        prefix='tables/nmf/discovery/l2/bicv/k/seeds/',
        each=PARAMS_K.each,
        jobs=PARAMS_K.batches,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --iterations-per-job {params.each} --output-prefix {params.prefix} --jobs {params.jobs}' + LOG



rule nmf_discovery_l2_bicv_q2_samples_k_pattern:
    output: 'tables/nmf/discovery/l2/bicv/q2/samples/k/{iteration}.feather'
    log: 'tables/nmf/discovery/l2/bicv/q2/samples/k/{iteration}.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/q2/samples/k/{iteration}.txt'
    input:
        rules.nmf_discovery_l2_scaled.output.flag,
        data=rules.nmf_discovery_l2_scaled.output.data,
        seeds=SEED_K,
    params:
        folds=PARAMS_K.folds,
        k_max=PARAMS_K.k_max,
    version: v('scripts/nmf/cv_nmf_bicv_alpha_seedlist.py')
    shell:
        'python scripts/nmf/cv_nmf_bicv_alpha_seedlist.py --input {input.data} --seedlist {input.seeds} --folds {params.folds} --output {output} --init nndsvd --l1-ratio 1 --alpha 0 --k `seq 2 {params.k_max}` --log {log} --cores 1' + LOG



rule nmf_discovery_l2_bicv_q2_combined_k_pattern:
    output: 'tables/nmf/discovery/l2/bicv/q2/combined/k.feather'
    log: 'tables/nmf/discovery/l2/bicv/q2/combined/k.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/q2/combined/k.txt'
    input: expand(rules.nmf_discovery_l2_bicv_q2_samples_k_pattern.output, iteration=K_ITERATION_RANGE)
    version: v('scripts/nmf/concatenate_q2.py')
    shell:
        'python scripts/nmf/concatenate_q2.py --inputs {input} --output {output}' + LOG



rule nmf_discovery_l2_k_parameter:
    input:
        PARAMETER_K,



# Cross-discovery to find alpha.

rule nmf_discovery_l2_bicv_alpha_seeds:
    output: expand(SEED_ALPHA, iteration=ALPHA_ITERATION_RANGE)
    log: 'tables/nmf/discovery/l2/bicv/alpha/seeds/seeds.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/alpha/seeds/seeds.txt'
    params:
        prefix='tables/nmf/discovery/l2/bicv/alpha/seeds/',
        each=PARAMS_ALPHA.each,
        jobs=PARAMS_ALPHA.batches,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --iterations-per-job {params.each} --output-prefix {params.prefix} --jobs {params.jobs}' + LOG



rule nmf_discovery_l2_bicv_q2_samples_alpha_pattern:
    output: 'tables/nmf/discovery/l2/bicv/q2/samples/alpha/{iteration}/{alpha}.feather'
    log: 'tables/nmf/discovery/l2/bicv/q2/samples/alpha/{iteration}/{alpha}.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/q2/samples/alpha/{iteration}/{alpha}.txt'
    input:
        rules.nmf_discovery_l2_scaled.output.flag,
        data=rules.nmf_discovery_l2_scaled.output.data,
        seeds=SEED_ALPHA,
        k=rules.nmf_discovery_l2_k_parameter.input,
    params:
        folds=PARAMS_ALPHA.folds,
    shell:
        'python scripts/nmf/cv_nmf_bicv_alpha_seedlist.py --input {input.data} --seedlist {input.seeds} --folds {params.folds} --output {output} --init nndsvd --l1-ratio 1 --alpha {wildcards.alpha} --k `cat {input.k}` --log {log} --cores 1' + LOG



rule nmf_discovery_l2_bicv_q2_combined_alpha_pattern:
    output: 'tables/nmf/discovery/l2/bicv/q2/combined/alpha.feather'
    log: 'tables/nmf/discovery/l2/bicv/q2/combined/alpha.log'
    benchmark: 'tables/nmf/discovery/l2/bicv/q2/combined/alpha.txt'
    input:
        expand(rules.nmf_discovery_l2_bicv_q2_samples_alpha_pattern.output, alpha=ALPHA_RANGE, iteration=ALPHA_ITERATION_RANGE)
    version: v('scripts/nmf/concatenate_q2.py')
    shell:
        'python scripts/nmf/concatenate_q2.py --inputs {input} --output {output}' + LOG



rule nmf_discovery_l2_alpha_parameter:
    input:
        PARAMETER_ALPHA,



# Compile seeds together.

rule nmf_discovery_l2_bicv_seeds:
    input:
        rules.nmf_discovery_l2_bicv_k_seeds.output,
        rules.nmf_discovery_l2_bicv_alpha_seeds.output,



# Summaries.

rule nmf_discovery_l2_bicv_summaries:
    input:
        expand('tables/nmf/discovery/l2/bicv/{parameter}/summaries.csv', parameter=PARAMETERS),



# NMF.

rule nmf_discovery_l2_nmf:
    input:
        expand('tables/nmf/discovery/l2/nmf/{file}', file=MODEL_FILES),



rule nmf_discovery_l2_joint_order:
    output: 'tables/nmf/discovery/l2/site_order.txt'
    input: 'parameters/nmf/k/discovery/l1.txt'
    shell:
        'seq 1 `cat {input}` > {output}'



rule nmf_discovery_l2_reordered:
    input:
        expand('tables/nmf/discovery/l2/reordered/{file}', file=MODEL_FILES),



rule nmf_discovery_l2_sparsified:
    input:
        expand('tables/nmf/discovery/l2/sparsified/{file}', file=MODEL_FILES),
        'tables/nmf/discovery/l2/sparsified/stats.csv',



# Figures.

rule nmf_discovery_l2_bicv_k_fig:
    input:
        'figures/nmf/discovery/l2/bicv/q2/k.pdf',



rule nmf_discovery_l2_bicv_alpha_fig:
    input:
        'figures/nmf/discovery/l2/bicv/q2/alpha.pdf',



rule nmf_discovery_l2_reordered_fig:
    input:
        'figures/nmf/discovery/l2/reordered/basis.pdf',



rule nmf_discovery_l2_sparsified_fig:
    input:
        'figures/nmf/discovery/l2/sparsified/correlations.pdf',
        'figures/nmf/discovery/l2/sparsified/basis.pdf',



# Link outputs.

rule nmf_discovery_l2_outputs_scaled_pattern:
    output: 'outputs/nmf/discovery/l2/scaled/{file}'
    input:
        'tables/nmf/discovery/l2/scaled/scaled.done',
        input='tables/nmf/discovery/l2/scaled/{file}',
    shell: LN_ALT



rule nmf_discovery_l2_outputs_model_pattern:
    output: 'outputs/nmf/discovery/l2/model/{file}'
    input:
        'tables/nmf/discovery/l2/sparsified/model.done',
        input='tables/nmf/discovery/l2/sparsified/{file}',
    shell: LN_ALT



rule nmf_discovery_l2_outputs:
    input:
        expand(rules.nmf_discovery_l2_outputs_scaled_pattern.output, file=SCALED_FILES),
        expand(rules.nmf_discovery_l2_outputs_model_pattern.output, file=MODEL_FILES),



# Targets.

rule nmf_discovery_l2_tables:
    input:
        rules.nmf_discovery_l2_bicv_seeds.input,
        rules.nmf_discovery_l2_reordered.input,
        rules.nmf_discovery_l2_sparsified.input,
        rules.nmf_discovery_l2_bicv_summaries.input



rule nmf_discovery_l2_parameters:
    input:
        rules.nmf_discovery_l2_k_parameter.input,
        rules.nmf_discovery_l2_alpha_parameter.input,



rule nmf_discovery_l2_figures:
    input:
        rules.nmf_discovery_l2_bicv_k_fig.input,
        rules.nmf_discovery_l2_bicv_alpha_fig.input,
        rules.nmf_discovery_l2_reordered_fig.input,
        rules.nmf_discovery_l2_sparsified_fig.input,



rule nmf_discovery_l2:
    input:
        rules.nmf_discovery_l2_inputs.input,
        rules.nmf_discovery_l2_tables.input,
        rules.nmf_discovery_l2_parameters.input,
        rules.nmf_discovery_l2_figures.input
