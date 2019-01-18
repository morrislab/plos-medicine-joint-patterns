"""
Projects the validation cohort data onto the discovery cohort factors.
"""

JOINTS_INPUT = 'inputs/validation_projections/data/joints.csv'
REFERENCE_SCALED_DATA = 'inputs/validation_projections/reference/scaled/{level}/{file}'
REFERENCE_SCALED_DATA_INPUT = expand(REFERENCE_SCALED_DATA, level='l1', file='data.csv')
REFERENCE_SCALED_PARAMETERS_INPUT = expand(REFERENCE_SCALED_DATA, level='{level}', file='parameters.csv')
MODEL_INPUT = 'inputs/validation_projections/models/{level}/model.pkl'

DISCOVERY_FREQUENCIES = 'inputs/validation_projections/frequencies/discovery.csv'
JOINT_POSITIONS = 'data/homunculus_positions/homunculus_positions.xlsx',
DIAGNOSES = 'inputs/validation_projections/diagnoses/validation.csv'

LEVELS = ['l1', 'l2']
FINAL_LEVEL = LEVELS[-1]

BOOTSTRAP_PARAMS = config.validation_projections.bootstrapped_comparisons



# Link inputs.

rule validation_projections_inputs_data:
    output: JOINTS_INPUT
    input: 'outputs/data/validation/joints.csv'
    shell: LN



rule validation_projections_inputs_reference_scaled_pattern:
    output: 'inputs/validation_projections/reference/scaled/{level}/{file}'
    input: 'outputs/nmf/discovery/{level}/scaled/{file}'
    shell: LN



rule validation_projections_inputs_reference_scaled:
    input:
        expand(rules.validation_projections_inputs_reference_scaled_pattern.output, level=LEVELS, file=['data.csv', 'parameters.csv']),



rule validation_projections_inputs_models_pattern:
    output: 'inputs/validation_projections/models/{level}/{file}'
    input: 'outputs/nmf/discovery/{level}/model/{file}'
    shell: LN



rule validation_projections_inputs_models:
    input:
        expand(rules.validation_projections_inputs_models_pattern.output, level=LEVELS, file=['model.pkl']),



rule validation_projections_inputs_frequencies_discovery:
    output: DISCOVERY_FREQUENCIES
    input: 'outputs/homunculi/frequencies/discovery.csv'
    shell: LN



rule validation_projections_inputs_diagnoses:
    output: DIAGNOSES
    input: 'outputs/diagnoses/roots/validation.csv'
    shell: LN



rule validation_projections_inputs:
    input:
        rules.validation_projections_inputs_data.output,
        rules.validation_projections_inputs_reference_scaled.input,
        rules.validation_projections_inputs_models.input,
        rules.validation_projections_inputs_frequencies_discovery.output,
        rules.validation_projections_inputs_diagnoses.output,



# Fix column names.

rule validation_projections_fixed_columns:
    output: 'tables/validation_projections/fixed_columns/data.csv'
    input: JOINTS_INPUT
    shell:
        'sed s/sternoclavicular/sterno/g {input} > {output}'



# Align the site involvement data to ensure that sites are in the same order as
# with the discovery cohort.

rule validation_projections_aligned:
    output: 'tables/validation_projections/aligned/l1.csv'
    log: 'tables/validation_projections/aligned/l1.log'
    benchmark: 'tables/validation_projections/aligned/l1.txt'
    input:
        data=rules.validation_projections_fixed_columns.output,
        reference=REFERENCE_SCALED_DATA_INPUT,
    version: v('scripts/validation_projections/align_data.py')
    shell:
        'python scripts/validation_projections/align_data.py --data-input {input.data} --reference-input {input.reference} --output {output}' + LOG



# Site involvements, in Feather format.

rule validation_projections_feather:
    output: 'tables/validation_projections/site_involvements.feather'
    input: rules.validation_projections_aligned.output
    run:
        import pandas
        X = pandas.read_csv(input[0])
        X['visit_id'] = 1
        X.to_feather(output[0])



# Scale data.

def validation_projections_scaled_pattern_input(wildcards):
    if wildcards.level == 'l1':
        return rules.validation_projections_aligned.output
    previous_level = int(wildcards.level.strip('l')) - 1
    return f'tables/validation_projections/scores/l{previous_level}.csv'

rule validation_projections_scaled_pattern:
    output: 'tables/validation_projections/scaled/{level}.csv'
    log: 'tables/validation_projections/scaled/{level}.log'
    benchmark: 'tables/validation_projections/scaled/{level}.txt'
    input:
        data=validation_projections_scaled_pattern_input,
        parameters=REFERENCE_SCALED_PARAMETERS_INPUT,
    version: v('scripts/validation_projections/scale_data.py')
    shell:
        'python scripts/validation_projections/scale_data.py --data-input {input.data} --parameter-input {input.parameters} --output {output}' + LOG




rule validation_projections_scaled:
    input:
        expand(rules.validation_projections_scaled_pattern.output, level=LEVELS),



# Projections to scores.

rule validation_projections_scores_pattern:
    output: 'tables/validation_projections/scores/{level}.csv'
    log: 'tables/validation_projections/scores/{level}.log'
    benchmark: 'tables/validation_projections/scores/{level}.txt'
    input:
        data=rules.validation_projections_scaled_pattern.output,
        model=MODEL_INPUT,
    version: v('scripts/validation_projections/get_scores.py')
    shell:
        'python scripts/validation_projections/get_scores.py --data-input {input.data} --model-input {input.model} --output {output}' + LOG



rule validation_projections_scores:
    input:
        expand(rules.validation_projections_scores_pattern.output, level=LEVELS),



# Patient group assignments.

rule validation_projections_clusters_pattern:
    output: 'tables/validation_projections/clusters/{level}.csv'
    log: 'tables/validation_projections/clusters/{level}.log'
    benchmark: 'tables/validation_projections/clusters/{level}.txt'
    input: rules.validation_projections_scores_pattern.output
    version: v('scripts/nmf/get_clusters.py')
    run:
        additional_parameters = '--letters' if wildcards.level == 'l2' else ''
        shell('python scripts/nmf/get_clusters.py --input {input} --output {output} --letters' + LOG)



rule validation_projections_clusters:
    input:
        expand(rules.validation_projections_clusters_pattern.output, level=LEVELS),



# Homunculi.

rule validation_projections_homunculi_frequency_pattern:
    output: 'tables/validation_projections/homunculi/frequencies/{level}.csv'
    log: 'tables/validation_projections/homunculi/frequencies/{level}.log'
    benchmark: 'tables/validation_projections/homunculi/frequencies/{level}.txt'
    input:
        data=rules.validation_projections_aligned.output,
        clusters=rules.validation_projections_clusters_pattern.output,
    version: v('scripts/homunculi/get_frequencies.py')
    shell:
        'python scripts/homunculi/get_frequencies.py --data-input {input.data} --cluster-input {input.clusters} --output {output}' + LOG



rule validation_projections_homunculi_frequencies:
    input:
        expand(rules.validation_projections_homunculi_frequency_pattern.output, level=LEVELS),



rule validation_projections_homunculi_pattern:
    output: 'figures/validation_projections/homunculi/{level}.pdf'
    log: 'figures/validation_projections/homunculi/{level}.log'
    benchmark: 'figures/validation_projections/homunculi/{level}.txt'
    input:
        data=rules.validation_projections_aligned.output,
        clusters=rules.validation_projections_clusters_pattern.output,
        joint_positions=JOINT_POSITIONS,
    params:
        width=7,
        height=7,
        max_point_size=2,
        trans='identity',
        clip=0.5
    version: v('scripts/homunculi/plot_signature_homunculi.R')
    shell:
        'Rscript scripts/homunculi/plot_signature_homunculi.R --input {input.data} --clusters {input.clusters} --joint-positions {input.joint_positions} --output {output} --figure-width {params.width} --figure-height {params.height} --max-point-size {params.max_point_size} --trans {params.trans} --clip {params.clip} --mirror' + LOG



rule validation_projections_homunculi:
    input:
        expand(rules.validation_projections_homunculi_pattern.output, level=LEVELS),



# Compare underlying joint involvements between the validation and discovery
# cohorts. Also bootstrap the results to calculate some stats.

rule validation_projections_involvement_comparisons:
    output: 'tables/validation_projections/comparisons.csv'
    log: 'tables/validation_projections/comparisons.log'
    benchmark: 'tables/validation_projections/comparisons.txt'
    input:
        validation_frequencies=expand(rules.validation_projections_homunculi_frequency_pattern.output, level=FINAL_LEVEL),
        discovery_frequencies=DISCOVERY_FREQUENCIES,
    version: v('scripts/validation_projections/compare_frequencies.py')
    shell:
        'python scripts/validation_projections/compare_frequencies.py --validation-input {input.validation_frequencies} --discovery-input {input.discovery_frequencies} --output {output}' + LOG



rule validation_projections_bootstrapped_comparisons_seeds:
    output: expand('tables/validation_projections/bootstrapped_comparisons/seeds/{split}.txt', split=range(1, BOOTSTRAP_PARAMS.splits + 1))
    log: 'tables/validation_projections/bootstrapped_comparisons/seeds/seeds.log'
    benchmark: 'tables/validation_projections/bootstrapped_comparisons/seeds/seeds.txt'
    params:
        output_prefix='tables/validation_projections/bootstrapped_comparisons/seeds/',
        splits=BOOTSTRAP_PARAMS.splits,
        each=BOOTSTRAP_PARAMS.each,
    version: v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.output_prefix} --jobs {params.splits} --iterations-per-job {params.each}' + LOG



rule validation_projections_bootstrapped_comparisons_samples_pattern:
    output: 'tables/validation_projections/bootstrapped_comparisons/samples/{split}.feather'
    log: 'tables/validation_projections/bootstrapped_comparisons/samples/{split}.log'
    benchmark: 'tables/validation_projections/bootstrapped_comparisons/samples/{split}.txt'
    input:
        data=rules.validation_projections_aligned.output,
        discovery_frequencies=DISCOVERY_FREQUENCIES,
        clusters=expand(rules.validation_projections_clusters_pattern.output, level=FINAL_LEVEL),
        seeds='tables/validation_projections/bootstrapped_comparisons/seeds/{split}.txt'
    version: v('scripts/validation_projections/bootstrap_distances.py')
    shell:
        'python scripts/validation_projections/bootstrap_distances.py --data-input {input.data} --discovery-frequency-input {input.discovery_frequencies} --cluster-input {input.clusters} --seeds {input.seeds} --output {output}' + LOG



rule validation_projections_bootstrapped_involvements_concatenated:
    output: 'tables/validation_projections/bootstrapped_comparisons/concatenated.feather'
    log: 'tables/validation_projections/bootstrapped_comparisons/concatenated.log'
    benchmark: 'tables/validation_projections/bootstrapped_comparisons/concatenated.txt'
    input: expand(rules.validation_projections_bootstrapped_comparisons_samples_pattern.output, split=range(1, BOOTSTRAP_PARAMS.splits + 1))
    version: v('scripts/validation_projections/concatenate_samples.py')
    run:
        inputs = ' '.join('--input {}'.format(x) for x in input)
        shell('python scripts/validation_projections/concatenate_samples.py {inputs} --output {output}' + LOG)



rule validation_projections_bootstrapped_comparisons_stats:
    output: 'tables/validation_projections/bootstrapped_comparisons/stats.xlsx'
    log: 'tables/validation_projections/bootstrapped_comparisons/stats.log'
    benchmark: 'tables/validation_projections/bootstrapped_comparisons/stats.txt'
    input:
        observed=rules.validation_projections_involvement_comparisons.output,
        samples=rules.validation_projections_bootstrapped_involvements_concatenated.output,
    version: v('scripts/validation_projections/get_stats.py')
    shell:
        'python scripts/validation_projections/get_stats.py --observed-input {input.observed} --sample-input {input.samples} --output {output}' + LOG



rule validation_projections_bootstrapped_comparisons:
    input:
        rules.validation_projections_bootstrapped_comparisons_seeds.output,
        expand(rules.validation_projections_bootstrapped_comparisons_samples_pattern.output, split=range(1, BOOTSTRAP_PARAMS.splits + 1)),
        rules.validation_projections_bootstrapped_involvements_concatenated.output,
        rules.validation_projections_bootstrapped_comparisons_stats.output,



# Variance explained.

rule validation_projections_variance_explained_scores_pattern:
    output: 'tables/validation_projections/variance_explained/scores/{level}.csv'
    log: 'tables/validation_projections/variance_explained/scores/{level}.log'
    benchmark: 'tables/validation_projections/variance_explained/scores/{level}.txt'
    input:
        data=rules.validation_projections_aligned.output,
        scores=rules.validation_projections_scores_pattern.output
    version: v('scripts/nmf/get_variance_explained_scores.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_scores.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



rule validation_projections_variance_explained_scores:
    input:
        expand(rules.validation_projections_variance_explained_scores_pattern.output, level=LEVELS),



rule validation_projections_variance_explained_clusters_pattern:
    output: 'tables/validation_projections/variance_explained/clusters/{level}.csv'
    log: 'tables/validation_projections/variance_explained/clusters/{level}.log'
    benchmark: 'tables/validation_projections/variance_explained/clusters/{level}.txt'
    input:
        data=rules.validation_projections_aligned.output,
        clusters=rules.validation_projections_clusters_pattern.output
    version: v('scripts/nmf/get_variance_explained_clusters.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_clusters.R --predictor-input {input.clusters} --response-input {input.data} --output {output}' + LOG



rule validation_projections_variance_explained_clusters:
    input:
        expand(rules.validation_projections_variance_explained_clusters_pattern.output, level=LEVELS),



rule validation_projections_variance_explained_ilar:
    output: 'tables/validation_projections/variance_explained/ilar.csv'
    log: 'tables/validation_projections/variance_explained/ilar.log'
    benchmark: 'tables/validation_projections/variance_explained/ilar.txt'
    input:
        data=JOINTS_INPUT,
        scores=DIAGNOSES,
    version: v('scripts/nmf/get_variance_explained_ilar.R')
    shell:
        'Rscript scripts/nmf/get_variance_explained_ilar.R --predictor-input {input.scores} --response-input {input.data} --output {output}' + LOG



rule validation_projections_variance_explained:
    input:
        rules.validation_projections_variance_explained_scores.input,
        rules.validation_projections_variance_explained_clusters.input,
        rules.validation_projections_variance_explained_ilar.output,



# Additional includes.

include: 'validation_projections/localizations.snakefile'



# Link outputs.

rule validation_projections_outputs_scores_pattern:
    output: 'outputs/validation_projections/scores/{level}.csv'
    input: rules.validation_projections_scores_pattern.output
    shell: LN



rule validation_projections_outputs_scores:
    input:
        expand(rules.validation_projections_outputs_scores_pattern.output, level=LEVELS),



rule validation_projections_outputs_clusters:
    output: 'outputs/validation_projections/clusters.csv'
    input: expand(rules.validation_projections_clusters_pattern.output, level=LEVELS[-1])
    shell: LN



rule validation_projections_outputs_localizations_assignments:
    output: 'outputs/validation_projections/localizations/assignments.csv'
    input: 'tables/validation_projections/localizations/classifications.csv'
    shell: LN



rule validation_projections_outputs_localizations_unified:
    output: 'outputs/validation_projections/localizations/unified.csv'
    input: 'tables/validation_projections/localizations/unified.csv'
    shell: LN



rule validation_projections_outputs_localizations:
    input:
        expand('outputs/validation_projections/localizations/{type}.csv', type=['assignments', 'unified']),



rule validation_projections_outputs:
    input:
        rules.validation_projections_outputs_scores.input,
        rules.validation_projections_outputs_clusters.output,
        rules.validation_projections_outputs_localizations.input,



# Targets.

rule validation_projections_tables:
    input:
        rules.validation_projections_fixed_columns.output,
        rules.validation_projections_aligned.output,
        rules.validation_projections_feather.output,
        rules.validation_projections_scaled.input,
        rules.validation_projections_scores.input,
        rules.validation_projections_clusters.input,
        rules.validation_projections_homunculi_frequencies.input,
        rules.validation_projections_variance_explained.input,
        rules.validation_projections_involvement_comparisons.output,
        rules.validation_projections_bootstrapped_comparisons.input,
        rules.validation_projections_localizations_tables.input,



rule validation_projections_parameters:
    input:
        rules.validation_projections_localizations_parameters.input,



rule validation_projections_figures:
    input:
        rules.validation_projections_homunculi.input,
        rules.validation_projections_localizations_figures.input,



rule validation_projections:
    input:
        rules.validation_projections_inputs.input,
        rules.validation_projections_tables.input,
        rules.validation_projections_parameters.input,
        rules.validation_projections_figures.input,
        rules.validation_projections_outputs.input,
