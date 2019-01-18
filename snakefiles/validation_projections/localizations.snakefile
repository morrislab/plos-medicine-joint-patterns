"""
Localizations for the validation cohort.
"""

LOCALIZED_THRESHOLD = expand('parameters/localizations/full/discovery/{level}.txt', level=FINAL_LEVEL)
PARTIAL_THRESHOLD = expand('parameters/localizations/partial/discovery/{level}.txt', level=FINAL_LEVEL)
BASIS = 'inputs/validation_projections/localizations/basis.csv'

LOCALIZATIONS = ['localized', 'partial', 'extended']



# Link inputs.

rule validation_projections_localizations_inputs_basis:
    output: BASIS
    input: expand('outputs/combined_bases/discovery/{level}.csv', level=FINAL_LEVEL)
    shell: LN



rule validation_projections_localizations_inputs:
    input:
        rules.validation_projections_localizations_inputs_basis.output,



# Generate the localizations.

rule validation_projections_localizations_classifications:
    output: 'tables/validation_projections/localizations/classifications.csv'
    log: 'tables/validation_projections/localizations/classifications.log'
    benchmark: 'tables/validation_projections/localizations/classifications.txt'
    input:
        data=rules.validation_projections_feather.output,
        basis=BASIS,
        clusters=expand(rules.validation_projections_clusters_pattern.output, level=FINAL_LEVEL),
        localized_threshold=LOCALIZED_THRESHOLD,
        partial_threshold=PARTIAL_THRESHOLD,
    version: v('scripts/localizations/get_partial_localizations.py')
    shell:
        'python scripts/localizations/get_partial_localizations.py --data-input {input.data} --basis-input {input.basis} --cluster-input {input.clusters} --localized-threshold `cat {input.localized_threshold}` --partial-threshold `cat {input.partial_threshold}` --output {output}' + LOG



rule validation_projections_localizations_unified:
    output: 'tables/validation_projections/localizations/unified.csv'
    log: 'tables/validation_projections/localizations/unified.log'
    benchmark: 'tables/validation_projections/localizations/unified.txt'
    input: rules.validation_projections_localizations_classifications.output
    version: v('scripts/localizations/get_unified_classifications.py')
    shell:
        'python scripts/localizations/get_unified_classifications.py --input {input} --output {output}' + LOG



# Unified classifications, split.

rule validation_projections_localizations_unified_split_pattern:
    output: 'tables/validation_projections/localizations/split/{localization}.csv'
    input: rules.validation_projections_localizations_unified.output
    shell:
        'head -n 1 {input} > {output} && awk /{wildcards.localization}/ {input} >> {output}'



rule validation_projections_localizations_unified_split:
    input:
        expand(rules.validation_projections_localizations_unified_split_pattern.output, localization=LOCALIZATIONS),



# Targets.

rule validation_projections_localizations_tables:
    input:
        rules.validation_projections_localizations_classifications.output,
        rules.validation_projections_localizations_unified.output,
        rules.validation_projections_localizations_unified_split.input,



rule validation_projections_localizations_parameters:
    input:



rule validation_projections_localizations_figures:
    input:



rule validation_projections_localizations:
    input:
        rules.validation_projections_localizations_inputs.input,
        rules.validation_projections_localizations_tables.input,
        rules.validation_projections_localizations_parameters.input,
        rules.validation_projections_localizations_figures.input
