"""
Bootstrap analysis to determine localization assignments: localized, partial, and
extended.
"""

PARAMS = config.localizations
LEVELS = PARAMS.levels
FINAL_LEVEL = LEVELS[-1]
THRESHOLDS = PARAMS.thresholds
BOOTSTRAP_ITER_ITEMS = list(range(1, PARAMS.bootstrap.iterations + 1))

DATA_INPUT = 'inputs/localizations/data/{cohort}.feather'
BASIS_INPUT = 'inputs/localizations/bases/{cohort}/{level}.csv'
CLUSTER_INPUT = 'inputs/localizations/clusters/{cohort}/{level}.csv'



# Link inputs.

rule localizations_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/{cohort}/joints.feather'
    shell: LN



rule localizations_inputs_basis_pattern_l1:
    output: 'inputs/localizations/bases/{cohort}/l1.csv'
    input: 'outputs/combined_bases/{cohort}/l1/basis.csv'
    shell: LN



rule localizations_inputs_basis_pattern:
    output: BASIS_INPUT
    input: expand('outputs/combined_bases/{{cohort}}/{level}.csv', level=LEVEL)
    shell: LN



rule localizations_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/levels/{cohort}/{level}.csv'
    shell: LN



rule localizations_inputs:
    input:
        expand(rules.localizations_inputs_data_pattern.output, cohort='discovery'),
        expand(rules.localizations_inputs_basis_pattern.output, cohort='discovery', level=LEVELS),
        expand(rules.localizations_inputs_clusters_pattern.output, cohort='discovery', level=LEVELS),


# Base assignments.

rule localizations_base_pattern:
    output: 'tables/localizations/base_assignments/{cohort}/{level}/threshold_{threshold}.csv'
    log: 'tables/localizations/base_assignments/{cohort}/{level}/threshold_{threshold}.log'
    benchmark: 'tables/localizations/base_assignments/{cohort}/{level}/threshold_{threshold}.txt'
    input:
        data=DATA_INPUT,
        basis=BASIS_INPUT,
        clusters=CLUSTER_INPUT,
    params:
        threshold=lambda wildcards: wildcards.threshold,
    version: v('scripts/localizations/get_base_classifications.py')
    shell:
        'python scripts/localizations/get_base_classifications.py --data-input {input.data} --basis-input {input.basis} --cluster-input {input.clusters} --threshold {params.threshold} --output {output}' + LOG



rule localizations_base:
    input:
        expand(rules.localizations_base_pattern.output, cohort='discovery', level=PARAMS.levels, threshold=PARAMS.thresholds),



# Bootstrapped analysis.

rule localizations_bootstrapped_seeds_pattern:
    output: dynamic('tables/localizations/seeds/{cohort}/seed_{iteration}.txt')
    params:
        prefix=lambda wildcards: f'tables/localizations/seeds/{wildcards.cohort}/seed_',
        each=lambda wildcards: config.localizations.bootstrap.each,
        jobs=lambda wildcards: config.localizations.bootstrap.iterations,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --iterations-per-job {params.each} --output-prefix {params.prefix} --jobs {params.jobs}' + LOG



rule localizations_bootstrapped_seeds:
    input:
        expand(rules.localizations_bootstrapped_seeds_pattern.output, cohort='discovery', iteration=BOOTSTRAP_ITER_ITEMS),



rule localizations_bootstrapped_samples_pattern:
    output: 'tables/localizations/samples/{cohort}/{level}/threshold_{threshold}_iteration_{iteration}.csv'
    log: 'tables/localizations/samples/{cohort}/{level}/threshold_{threshold}_iteration_{iteration}.log'
    benchmark: 'tables/localizations/samples/{cohort}/{level}/threshold_{threshold}_iteration_{iteration}.txt'
    input:
        seeds=rules.localizations_bootstrapped_seeds_pattern.output,
        data=rules.localizations_base_pattern.output,
    params:
        threshold=lambda wildcards: wildcards.threshold,
    version: v('scripts/localizations/bootstrap_counts.py')
    shell:
        'python scripts/localizations/bootstrap_counts.py --data-input {input.data} --seed-input {input.seeds} --output {output}' + LOG



rule localizations_bootstrapped_samples:
    input:
        expand(rules.localizations_bootstrapped_samples_pattern.output, cohort='discovery', level=LEVELS, threshold=THRESHOLDS, iteration=BOOTSTRAP_ITER_ITEMS),



def localizations_bootstrapped_combined_pattern_input(wildcards):
    return expand(rules.localizations_bootstrapped_samples_pattern.output, threshold=config.localizations.thresholds, iteration=range(1, config.localizations.bootstrap.iterations + 1), cohort=wildcards.cohort, level=wildcards.level)

rule localizations_bootstrapped_combined_pattern:
    output: 'tables/localizations/combined/{cohort}/{level}.csv'
    log: 'tables/localizations/combined/{cohort}/{level}.log'
    benchmark: 'tables/localizations/combined/{cohort}/{level}.txt'
    input: localizations_bootstrapped_combined_pattern_input
    run:
        head_cmd = 'head -n 1 ' + input[0] + ' > {output}'
        tail_cmds = ' && '.join('tail -n +2 ' + x + ' >> {output}' for x in input)
        shell(head_cmd + ' && ' + tail_cmds)



rule localizations_bootstrapped_combined:
    input:
        expand(rules.localizations_bootstrapped_combined_pattern.output, cohort='discovery', level=LEVELS),



# Statistics.

rule localizations_bootstrapped_stats_pattern:
    output: 'tables/localizations/stats/{cohort}/{level}.csv'
    log: 'tables/localizations/stats/{cohort}/{level}.log'
    benchmark: 'tables/localizations/stats/{cohort}/{level}.txt'
    input: rules.localizations_bootstrapped_combined_pattern.output
    version: v('scripts/localizations/get_bootstrapped_stats.R')
    shell:
        'Rscript scripts/localizations/get_bootstrapped_stats.R --input {input} --output {output}' + LOG



rule localizations_bootstrapped_stats:
    input:
        expand(rules.localizations_bootstrapped_stats_pattern.output, cohort='discovery', level=LEVELS),



# Figure of % of patients vs. threshold.

rule localizations_bootstrapped_fig_pattern:
    output: 'figures/localizations/stats/{cohort}/{level}.pdf'
    log: 'figures/localizations/stats/{cohort}/{level}.log'
    benchmark: 'figures/localizations/stats/{cohort}/{level}.txt'
    input: rules.localizations_bootstrapped_combined_pattern.output
    params:
        width=3,
        height=6,
        denominator=640,
    version: v('scripts/localizations/plot_bootstrapped_stats.R')
    shell:
        'Rscript scripts/localizations/plot_bootstrapped_stats.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height} --denominator {params.denominator}' + LOG



rule localizations_bootstrapped_fig:
    input:
        expand(rules.localizations_bootstrapped_fig_pattern.output, cohort='discovery', level=LEVELS),



# Optimal thresholds for full and partial localizations. Partial localization
# is based on the most negative slope from bootstrap analysis.

rule localizations_threshold_full_pattern:
    output: 'parameters/localizations/full/{cohort}/{level}.txt'
    log: 'parameters/localizations/full/{cohort}/{level}.log'
    benchmark: 'parameters/localizations/full/{cohort}/{level}.benchmark.txt'
    input: rules.localizations_bootstrapped_stats_pattern.output
    version: v('scripts/localizations/get_optimal_full_threshold.py')
    shell:
        'python scripts/localizations/get_optimal_full_threshold.py --input {input} --output {output}' + LOG



rule localizations_threshold_partial_pattern:
    output: 'parameters/localizations/partial/{cohort}/{level}.txt'
    log: 'parameters/localizations/partial/{cohort}/{level}.log'
    benchmark: 'parameters/localizations/partial/{cohort}/{level}.benchmark.txt'
    input: rules.localizations_bootstrapped_stats_pattern.output
    version: v('scripts/localizations/get_optimal_partial_threshold.py')
    shell:
        'python scripts/localizations/get_optimal_partial_threshold.py --input {input} --output {output}' + LOG



rule localizations_thresholds:
    input:
        expand(rules.localizations_threshold_full_pattern.output, cohort='discovery', level=LEVELS),
        expand(rules.localizations_threshold_partial_pattern.output, cohort='discovery', level=LEVELS),



# Cluster assignments with localizations.

rule localizations_assignments_pattern:
    output: 'tables/localizations/assignments/{cohort}/{level}.csv'
    log: 'tables/localizations/assignments/{cohort}/{level}.log'
    benchmark: 'tables/localizations/assignments/{cohort}/{level}.txt'
    input:
        data=DATA_INPUT,
        basis=BASIS_INPUT,
        clusters=CLUSTER_INPUT,
        localized_threshold=rules.localizations_threshold_full_pattern.output,
        partial_threshold=rules.localizations_threshold_partial_pattern.output,
    version: v('scripts/localizations/get_partial_localizations.py')
    shell:
        'python scripts/localizations/get_partial_localizations.py --data-input {input.data} --basis-input {input.basis} --cluster-input {input.clusters} --localized-threshold `cat {input.localized_threshold}` --partial-threshold `cat {input.partial_threshold}` --output {output}' + LOG



rule localizations_assignments:
    input:
        expand(rules.localizations_assignments_pattern.output, cohort='discovery', level=LEVELS),



# Patient counts.

rule localizations_patient_counts_pattern:
    output: 'tables/localizations/patient_counts/{cohort}/{level}.csv'
    log: 'tables/localizations/patient_counts/{cohort}/{level}.log'
    benchmark: 'tables/localizations/patient_counts/{cohort}/{level}.txt'
    input: rules.localizations_assignments_pattern.output
    version: v('scripts/localizations/get_patient_counts.py')
    shell:
        'python scripts/localizations/get_patient_counts.py --input {input} --output {output}' + LOG



rule localizations_patient_counts:
    input:
        expand(rules.localizations_patient_counts_pattern.output, cohort='discovery', level=LEVELS),



rule localizations_patient_counts_fig_pattern:
    output: 'figures/localizations/patient_counts/{cohort}/{level}.pdf'
    log: 'figures/localizations/patient_counts/{cohort}/{level}.log'
    benchmark: 'figures/localizations/patient_counts/{cohort}/{level}.txt'
    input: rules.localizations_patient_counts_pattern.output
    params:
        width=6,
        height=6,
    version: v('scripts/localizations/plot_patient_counts.R')
    shell:
        'Rscript scripts/localizations/plot_patient_counts.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height}' + LOG



rule localizations_patient_counts_fig:
    input:
        expand(rules.localizations_patient_counts_fig_pattern.output, cohort='discovery', level=LEVELS)



# Unified classifications.

rule localizations_unified_pattern:
    output: 'tables/localizations/unified/{cohort}/{level}.csv'
    log: 'tables/localizations/unified/{cohort}/{level}.log'
    benchmark: 'tables/localizations/unified/{cohort}/{level}.txt'
    input: rules.localizations_assignments_pattern.output
    version: v('scripts/localizations/get_unified_classifications.py')
    shell:
        'python scripts/localizations/get_unified_classifications.py --input {input} --output {output}' + LOG



rule localizations_unified:
    input:
        expand(rules.localizations_unified_pattern.output, cohort='discovery', level=LEVELS)



# Stats to determine which groups are more localized than others.

rule localizations_group_stats_pattern:
    output: 'tables/localizations/group_stats/{cohort}/{level}.xlsx'
    log: 'tables/localizations/group_stats/{cohort}/{level}.log'
    benchmark: 'tables/localizations/group_stats/{cohort}/{level}.txt'
    input: rules.localizations_assignments_pattern.output
    params:
        iterations=PARAMS.stats.iterations,
    threads: 96
    version: v('scripts/localizations/do_group_stats.R')
    shell:
        'Rscript scripts/localizations/do_group_stats.R --input {input} --output {output} --threads {threads} --iterations {params.iterations}' + LOG



rule localizations_group_stats:
    input:
        expand(rules.localizations_group_stats_pattern.output, cohort='discovery', level=LEVELS)



include: 'localizations/counts.snakefile'



# Link outputs.

rule localizations_outputs_assignments_levels_pattern:
    output: 'outputs/localizations/assignments/levels/{cohort}/{level}.csv'
    input: rules.localizations_assignments_pattern.output
    shell: LN



rule localizations_outputs_assignments_levels:
    input:
        expand(rules.localizations_outputs_assignments_levels_pattern.output, cohort=COHORTS, level=LEVELS),



rule localizations_outputs_assignments_pattern:
    output: 'outputs/localizations/assignments/{cohort}.csv'
    input: expand(rules.localizations_assignments_pattern.output, cohort='{cohort}', level=FINAL_LEVEL)
    shell: LN



rule localizations_outputs_unified_pattern:
    output: 'outputs/localizations/unified/{cohort}.csv'
    input: expand(rules.localizations_unified_pattern.output, cohort='{cohort}', level=FINAL_LEVEL)
    shell: LN



rule localizations_outputs:
    input:
        rules.localizations_outputs_assignments_levels.input,
        expand(rules.localizations_outputs_assignments_pattern.output, cohort='discovery'),
        expand(rules.localizations_outputs_unified_pattern.output, cohort='discovery'),



# Targets.

rule localizations_tables:
    input:
        rules.localizations_base.input,
        rules.localizations_bootstrapped_seeds.input,
        rules.localizations_bootstrapped_samples.input,
        rules.localizations_bootstrapped_combined.input,
        rules.localizations_bootstrapped_stats.input,
        rules.localizations_assignments.input,
        rules.localizations_patient_counts.input,
        rules.localizations_unified.input,
        rules.localizations_group_stats.input,
        rules.localizations_counts_tables.input,



rule localizations_parameters:
    input:
        rules.localizations_thresholds.input,
        rules.localizations_counts_parameters.input,



rule localizations_figures:
    input:
        rules.localizations_bootstrapped_fig.input,
        rules.localizations_patient_counts_fig.input,
        rules.localizations_counts_figures.input,



rule localizations:
    input:
        rules.localizations_inputs.input,
        rules.localizations_tables.input,
        rules.localizations_parameters.input,
        rules.localizations_figures.input,
        rules.localizations_outputs.input,
