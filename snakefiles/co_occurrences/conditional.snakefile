"""
Additional analyses with conditional probabilities.
"""

SIDES = ['same', 'opposite']

JOBS = config.co_occurrences.conditional.additional.jobs
ITERATIONS_PER_JOB = config.co_occurrences.conditional.additional.iterations_per_job

JOB_NUMBERS = list(range(1, JOBS + 1))

INPUT = 'inputs/co_occurrences/conditional/co_occurrences/{cohort}.feather'
DISCOVERY_INPUT = expand(INPUT, cohort='discovery')



# Link the data.

rule co_occurrences_conditional_inputs_data_discovery:
    output: DISCOVERY_INPUT
    input: 'tables/co_occurrences/co_occurrences/discovery.feather'
    shell: LN



rule co_occurrences_conditional_inputs_data:
    input:
        DISCOVERY_INPUT,



rule co_occurrences_conditional_inputs:
    input:
        rules.co_occurrences_conditional_inputs_data.input,



# Annotate the data.

rule co_occurrences_conditional_annotated_pattern:
    output: 'tables/co_occurrences/conditional/annotated/{cohort}.feather'
    log: 'tables/co_occurrences/conditional/annotated/{cohort}.log'
    benchmark: 'tables/co_occurrences/conditional/annotated/{cohort}.txt'
    input: INPUT
    version: v('scripts/co_occurrences/conditional/annotate.py')
    shell:
        'python scripts/co_occurrences/conditional/annotate.py --input {input} --output {output}' + LOG



rule co_occurrences_conditional_annotated:
    input:
        expand(rules.co_occurrences_conditional_annotated_pattern.output, cohort='discovery'),



# Split the data by sides.

rule co_occurrences_conditional_split_pattern:
    output: 'tables/co_occurrences/conditional/split/{cohort}/{sides}.feather'
    log: 'tables/co_occurrences/conditional/split/{cohort}/{sides}.log'
    benchmark: 'tables/co_occurrences/conditional/split/{cohort}/{sides}.txt'
    input: rules.co_occurrences_conditional_annotated_pattern.output
    version: v('scripts/co_occurrences/conditional/get_split_data.py')
    shell:
        'python scripts/co_occurrences/conditional/get_split_data.py --input {input} --output {output} --sides {wildcards.sides}' + LOG



rule co_occurrences_conditional_split:
    input:
        expand(rules.co_occurrences_conditional_split_pattern.output, cohort='discovery', sides=SIDES),



# Generate base distances.

rule co_occurrences_conditional_base_distances_pattern:
    output: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.feather'
    log: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.log'
    benchmark: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.txt'
    input: rules.co_occurrences_conditional_split_pattern.output
    version: v('scripts/co_occurrences/conditional/get_base_distance.py')
    shell:
        'python scripts/co_occurrences/conditional/get_base_distance.py --input {input} --output {output}' + LOG



rule co_occurrences_conditional_base_distances_xls_pattern:
    output: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.xlsx'
    log: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.log'
    benchmark: 'tables/co_occurrences/conditional/base_distances/{cohort}/{sides}.txt'
    input: rules.co_occurrences_conditional_base_distances_pattern.output
    version: v('scripts/general/feather_to_excel.py')
    shell:
        'python scripts/general/feather_to_excel.py --input {input} --output {output}' + LOG



rule co_occurrences_conditional_base_distances:
    input:
        expand(rules.co_occurrences_conditional_base_distances_pattern.output, cohort='discovery', sides=SIDES),
        expand(rules.co_occurrences_conditional_base_distances_xls_pattern.output, cohort='discovery', sides=SIDES),



# Obtain seeds for the analysis.

rule co_occurrences_conditional_seeds:
    output:
        expand('tables/co_occurrences/conditional/seeds/{job}.txt', job=JOB_NUMBERS),
        flag=touch('tables/co_occurrences/conditional/seeds.done'),
    log: 'tables/co_occurrences/conditional/seeds/seeds.log'
    benchmark: 'tables/co_occurrences/conditional/seeds/seeds.txt'
    params:
        output_prefix='tables/co_occurrences/conditional/seeds/',
        jobs=JOBS,
        iterations_per_job=ITERATIONS_PER_JOB,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.output_prefix} --jobs {params.jobs} --iterations-per-job {params.iterations_per_job}' + LOG



# Run the permutation analysis.

rule co_occurrences_conditional_samples_pattern:
    output: 'tables/co_occurrences/conditional/samples/{cohort}/{sides}/{job}.feather'
    log: 'tables/co_occurrences/conditional/samples/{cohort}/{sides}/{job}.log'
    benchmark: 'tables/co_occurrences/conditional/samples/{cohort}/{sides}/{job}.txt'
    input:
        rules.co_occurrences_conditional_seeds.output.flag,
        data=rules.co_occurrences_conditional_split_pattern.output,
        seeds='tables/co_occurrences/conditional/seeds/{job}.txt',
    version: v('scripts/co_occurrences/conditional/get_permutation_samples.py')
    shell:
        'python scripts/co_occurrences/conditional/get_permutation_samples.py --data-input {input.data} --seed-input {input.seeds} --output {output}' + LOG



rule co_occurrences_conditional_samples:
    input:
        expand(rules.co_occurrences_conditional_samples_pattern.output, cohort='discovery', sides=SIDES, job=JOB_NUMBERS),



rule co_occurrences_conditional_concatenated_pattern:
    output: 'tables/co_occurrences/conditional/concatenated/{cohort}/{sides}.feather'
    log: 'tables/co_occurrences/conditional/concatenated/{cohort}/{sides}.log'
    benchmark: 'tables/co_occurrences/conditional/concatenated/{cohort}/{sides}.txt'
    input: expand(rules.co_occurrences_conditional_samples_pattern.output, cohort='{cohort}', sides='{sides}', job=JOB_NUMBERS)
    version: v('scripts/general/concatenate_feather.py')
    run:
        inputs = ' '.join(f'--input {x}' for x in input)
        shell('python scripts/general/concatenate_feather.py {inputs} --output {output}' + LOG)



rule co_occurrences_conditional_concatenated:
    input:
        expand(rules.co_occurrences_conditional_concatenated_pattern.output, cohort='discovery', sides=SIDES),



# Calculate statistics.

rule co_occurrences_conditional_stats_pattern:
    output: 'tables/co_occurrences/conditional/stats/{cohort}/{sides}.xlsx'
    log: 'tables/co_occurrences/conditional/stats/{cohort}/{sides}.log'
    benchmark: 'tables/co_occurrences/conditional/stats/{cohort}/{sides}.txt'
    input:
        base=rules.co_occurrences_conditional_base_distances_pattern.output,
        samples=rules.co_occurrences_conditional_concatenated_pattern.output,
    version: v('scripts/co_occurrences/conditional/get_stats.py')
    shell:
        'python scripts/co_occurrences/conditional/get_stats.py --base-input {input.base} --sample-input {input.samples} --output {output}' + LOG



rule co_occurrences_conditional_stats:
    input:
        expand(rules.co_occurrences_conditional_stats_pattern.output, cohort='discovery', sides=SIDES),



# Targets.

rule co_occurrences_conditional_tables:
    input:
        rules.co_occurrences_conditional_seeds.input,
        rules.co_occurrences_conditional_split.input,
        rules.co_occurrences_conditional_annotated.input,
        rules.co_occurrences_conditional_base_distances.input,
        rules.co_occurrences_conditional_samples.input,
        rules.co_occurrences_conditional_concatenated.input,
        rules.co_occurrences_conditional_stats.input,



rule co_occurrences_conditional_parameters:
    input:



rule co_occurrences_conditional_figures:
    input:



rule co_occurrences_conditional:
    input:
        rules.co_occurrences_conditional_inputs.input,
        rules.co_occurrences_conditional_tables.input,
        rules.co_occurrences_conditional_parameters.input,
        rules.co_occurrences_conditional_figures.input,
