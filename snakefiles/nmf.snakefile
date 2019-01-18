"""
Non-negative matrix factorization.
"""

K_COMBINED_Q2 = 'tables/nmf/{cohort}/{level}/bicv/q2/combined/k.feather'
ALPHA_COMBINED_Q2 = 'tables/nmf/{cohort}/{level}/bicv/q2/combined/alpha.feather'

K_PARAMETER = 'parameters/nmf/k/{cohort}/{level}.txt'
ALPHA_PARAMETER = 'parameters/nmf/alpha/{cohort}/{level}.txt'

SITE_ORDER = 'tables/nmf/{cohort}/{level}/site_order.txt'
SCALED_FILES = ['data.csv', 'parameters.csv']
MODEL_FILES = ['model.pkl', 'basis.csv', 'scores.csv', 'model.done']
PARAMETERS = ['k', 'alpha']



# Link inputs.

rule nmf_inputs:
    input:



# Generalized definitions for conducting cross-validation.

rule nmf_bicv_q2_k_fig_pattern:
    output: 'figures/nmf/{cohort}/{level}/bicv/q2/k.pdf'
    log: 'figures/nmf/{cohort}/{level}/bicv/q2/k.log'
    benchmark: 'figures/nmf/{cohort}/{level}/bicv/q2/k.txt'
    input: K_COMBINED_Q2
    params:
        width=3,
        height=3,
    version: v('scripts/nmf/plot_q2_nmf_k.R')
    shell:
        'Rscript scripts/nmf/plot_q2_nmf_k.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule nmf_parameters_k_pattern:
    output: 'parameters/nmf/k/{cohort}/{level}.txt'
    log: 'parameters/nmf/k/{cohort}/{level}.log'
    benchmark: 'parameters/nmf/k/{cohort}/{level}.benchmark.txt'
    input: K_COMBINED_Q2
    version: v('scripts/nmf/get_k.py')
    shell:
        'python scripts/nmf/get_k.py --input {input} --output {output}' + LOG



rule nmf_bicv_q2_alpha_fig_pattern:
    output: 'figures/nmf/{cohort}/{level}/bicv/q2/alpha.pdf'
    log: 'figures/nmf/{cohort}/{level}/bicv/q2/alpha.log'
    benchmark: 'figures/nmf/{cohort}/{level}/bicv/q2/alpha.txt'
    input: ALPHA_COMBINED_Q2
    version: v('scripts/nmf/plot_q2_nmf_alpha.R')
    params:
        width=3,
        height=3,
    shell:
        'Rscript scripts/nmf/plot_q2_nmf_alpha.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule nmf_parameters_alpha_pattern:
    output: 'parameters/nmf/alpha/{cohort}/{level}.txt'
    log: 'parameters/nmf/alpha/{cohort}/{level}.log'
    benchmark: 'parameters/nmf/alpha/{cohort}/{level}.benchmark.txt'
    input: ALPHA_COMBINED_Q2
    version: v('scripts/nmf/get_alpha.py')
    shell:
        'python scripts/nmf/get_alpha.py --input {input} --output {output}' + LOG



rule nmf_bicv_q2_summary_pattern:
    output: 'tables/nmf/{cohort}/{level}/bicv/{parameter}/summaries.csv'
    log: 'tables/nmf/{cohort}/{level}/bicv/{parameter}/summaries.log'
    benchmark: 'tables/nmf/{cohort}/{level}/bicv/{parameter}/summaries.txt'
    input: 'tables/nmf/{cohort}/{level}/bicv/q2/combined/{parameter}.feather'
    version: v('scripts/nmf/summarize_bicv.py')
    shell:
        'python scripts/nmf/summarize_bicv.py --input {input} --output {output} --parameter {wildcards.parameter}' + LOG



# Generalized definitions for conducting NMF.

rule nmf_nmf_pattern:
    output:
        model='tables/nmf/{cohort}/{level}/nmf/model.pkl',
        basis='tables/nmf/{cohort}/{level}/nmf/basis.csv',
        scores='tables/nmf/{cohort}/{level}/nmf/scores.csv',
        flag=touch('tables/nmf/{cohort}/{level}/nmf/model.done'),
    log: 'tables/nmf/{cohort}/{level}/nmf/model.log'
    benchmark: 'tables/nmf/{cohort}/{level}/nmf/model.txt'
    input:
        'tables/nmf/{cohort}/{level}/scaled/scaled.done',
        data='tables/nmf/{cohort}/{level}/scaled/data.csv',
        k=rules.nmf_parameters_k_pattern.output,
        alpha=rules.nmf_parameters_alpha_pattern.output,
    shell:
        'python scripts/nmf/nmf.py --input {input.data} --k `cat {input.k}` --alpha `cat {input.alpha}` --model-output {output.model} --basis-output {output.basis} --score-output {output.scores} --init nndsvd --l1-ratio 1' + LOG



rule nmf_reordered_pattern:
    output:
        model='tables/nmf/{cohort}/{level}/reordered/model.pkl',
        basis='tables/nmf/{cohort}/{level}/reordered/basis.csv',
        scores='tables/nmf/{cohort}/{level}/reordered/scores.csv',
        flag=touch('tables/nmf/{cohort}/{level}/reordered/model.done'),
    log: 'tables/nmf/{cohort}/{level}/reordered/model.done'
    benchmark: 'tables/nmf/{cohort}/{level}/reordered/model.txt'
    input:
        rules.nmf_nmf_pattern.output.flag,
        data=rules.nmf_nmf_pattern.output.model,
        basis=rules.nmf_nmf_pattern.output.basis,
        scores=rules.nmf_nmf_pattern.output.scores,
        site_order=SITE_ORDER,
    shell:
        'python scripts/nmf/reorder_factors.py --model-input {input.data} --basis-input {input.basis} --score-input {input.scores} --joint-order-input {input.site_order} --model-output {output.model} --basis-output {output.basis} --score-output {output.scores}' + LOG



rule nmf_reordered_basis_fig_pattern:
    output: 'figures/nmf/{cohort}/{level}/reordered/basis.pdf'
    log: 'figures/nmf/{cohort}/{level}/reordered/basis.log'
    benchmark: 'figures/nmf/{cohort}/{level}/reordered/basis.txt'
    input:
        rules.nmf_reordered_pattern.output.flag,
        basis=rules.nmf_reordered_pattern.output.basis,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=6,
        option=VIRIDIS_PALETTE,
    version: v('scripts/nmf/plot_basis_asis.R')
    shell:
        'Rscript scripts/nmf/plot_basis_asis.R --input {input.basis} --site-order {input.site_order} --output {output} --width {params.width} --height {params.height} --colour-scale --max-scaling --option {params.option}' + LOG



# Generalized rules for sparsification.

rule nmf_sparsified_pattern:
    output:
        model='tables/nmf/{cohort}/{level}/sparsified/model.pkl',
        basis='tables/nmf/{cohort}/{level}/sparsified/basis.csv',
        scores='tables/nmf/{cohort}/{level}/sparsified/scores.csv',
        flag=touch('tables/nmf/{cohort}/{level}/sparsified/model.done'),
    log: 'tables/nmf/{cohort}/{level}/sparsified/model.log'
    benchmark: 'tables/nmf/{cohort}/{level}/sparsified/model.txt'
    input:
        'tables/nmf/{cohort}/{level}/scaled/scaled.done',
        rules.nmf_reordered_pattern.output.flag,
        data='tables/nmf/{cohort}/{level}/scaled/data.csv',
        model=rules.nmf_reordered_pattern.output.model,
    params:
        coefficient=0.5,
    version: v('scripts/nmf/sparsify_nmf_representative_sites.py')
    shell:
        'python scripts/nmf/sparsify_nmf_representative_sites.py --data-input {input.data} --model-input {input.model} --model-output {output.model} --basis-output {output.basis} --score-output {output.scores} --coefficient {params.coefficient}' + LOG



rule nmf_sparsified_correlations_pattern:
    output: 'tables/nmf/{cohort}/{level}/sparsified/stats.csv',
    log: 'tables/nmf/{cohort}/{level}/sparsified/stats.log',
    benchmark: 'tables/nmf/{cohort}/{level}/sparsified/stats.txt',
    input:
        rules.nmf_reordered_pattern.output.flag,
        rules.nmf_sparsified_pattern.output.flag,
        unsparsified_basis=rules.nmf_reordered_pattern.output.scores,
        sparsified_basis=rules.nmf_sparsified_pattern.output.scores,
    version: v('scripts/nmf/correlate_sparsified_factors.R')
    shell:
        'Rscript scripts/nmf/correlate_sparsified_factors.R --unsparsified-input {input.unsparsified_basis} --sparsified-input {input.sparsified_basis} --output {output}' + LOG



rule nmf_sparsified_correlations_fig_pattern:
    output: 'figures/nmf/{cohort}/{level}/sparsified/correlations.pdf'
    log: 'figures/nmf/{cohort}/{level}/sparsified/correlations.log'
    benchmark: 'figures/nmf/{cohort}/{level}/sparsified/correlations.txt'
    input:
        rules.nmf_reordered_pattern.output.flag,
        rules.nmf_sparsified_pattern.output.flag,
        unsparsified_basis=rules.nmf_reordered_pattern.output.scores,
        sparsified_basis=rules.nmf_sparsified_pattern.output.scores,
    params:
        width=3,
        height=8,
        ncol=3,
        option=VIRIDIS_PALETTE,
    version: v('scripts/nmf/plot_sparsification_correlations.R')
    shell:
        'Rscript scripts/nmf/plot_sparsification_correlations.R --unsparsified-input {input.unsparsified_basis} --sparsified-input {input.sparsified_basis} --output {output} --figure-width {params.width} --figure-height {params.height} --ncol {params.ncol} --colour-scale --option {params.option}' + LOG



rule nmf_sparsified_basis_fig_pattern:
    output: 'figures/nmf/{cohort}/{level}/sparsified/basis.pdf'
    log: 'figures/nmf/{cohort}/{level}/sparsified/basis.log'
    benchmark: 'figures/nmf/{cohort}/{level}/sparsified/basis.txt'
    input:
        rules.nmf_sparsified_pattern.output.flag,
        basis=rules.nmf_sparsified_pattern.output.basis,
        site_order=SITE_ORDER,
    params:
        width=6,
        height=6,
        option=VIRIDIS_PALETTE,
    version: v('scripts/nmf/plot_basis_asis.R')
    shell:
        'Rscript scripts/nmf/plot_basis_asis.R --input {input.basis} --site-order {input.site_order} --output {output} --width {params.width} --height {params.height} --colour-scale --max-scaling --option {params.option}' + LOG



# Includes.

include: 'nmf/discovery.snakefile'
include: 'nmf/validation.snakefile'
include: 'nmf/scatterplots.snakefile'



# Link outputs.

rule nmf_outputs:
    input:
        rules.nmf_discovery_outputs.input,
        rules.nmf_validation_outputs.input,



# Targets.

rule nmf_tables:
    input:
        rules.nmf_discovery_tables.input,
        rules.nmf_validation_tables.input,
        rules.nmf_scatterplots_tables.input,



rule nmf_parameters:
    input:
        rules.nmf_discovery_parameters.input,
        rules.nmf_validation_parameters.input,
        rules.nmf_scatterplots_parameters.input,



rule nmf_figures:
    input:
        rules.nmf_discovery_figures.input,
        rules.nmf_validation_figures.input,
        rules.nmf_scatterplots_figures.input,



rule nmf:
    input:
        rules.nmf_inputs.input,
        rules.nmf_tables.input,
        rules.nmf_parameters.input,
        rules.nmf_figures.input,
        rules.nmf_outputs.input,
