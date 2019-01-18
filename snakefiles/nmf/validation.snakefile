"""
NMF on the validation cohort.
"""

include: 'validation/l1.snakefile'
include: 'validation/l2.snakefile'



# Link inputs.

rule nmf_validation_inputs:
    input:



# Link outputs.

rule nmf_validation_outputs:
    input:
        rules.nmf_validation_l1_outputs.input,
        rules.nmf_validation_l2_outputs.input,



# Targets.

rule nmf_validation_tables:
    input:
        rules.nmf_validation_l1_tables.input,
        rules.nmf_validation_l2_tables.input,



rule nmf_validation_parameters:
    input:
        rules.nmf_validation_l1_parameters.input,
        rules.nmf_validation_l2_parameters.input,



rule nmf_validation_figures:
    input:
        rules.nmf_validation_l1_figures.input,
        rules.nmf_validation_l2_figures.input,



rule nmf_validation:
    input:
        rules.nmf_validation_inputs.input,
        rules.nmf_validation_tables.input,
        rules.nmf_validation_parameters.input,
        rules.nmf_validation_figures.input,
        rules.nmf_validation_outputs.input,
