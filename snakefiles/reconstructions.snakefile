"""
Reconstructions of the input data.
"""

include: 'reconstructions/discovery.snakefile'
include: 'reconstructions/validation.snakefile'
include: 'reconstructions/validation_projections.snakefile'
include: 'reconstructions/diagnoses.snakefile'



rule reconstructions_tables:
    input:
        rules.reconstructions_discovery_tables.input,
        rules.reconstructions_validation_tables.input,
        rules.reconstructions_validation_projections_tables.input,
        rules.reconstructions_diagnoses_tables.input,



rule reconstructions_parameters:
    input:
        rules.reconstructions_discovery_parameters.input,
        rules.reconstructions_validation_parameters.input,
        rules.reconstructions_validation_projections_parameters.input,
        rules.reconstructions_diagnoses_parameters.input,



rule reconstructions_figures:
    input:
        rules.reconstructions_discovery_figures.input,
        rules.reconstructions_validation_figures.input,
        rules.reconstructions_validation_projections_figures.input,
        rules.reconstructions_diagnoses_figures.input,



rule reconstructions:
    input:
        rules.reconstructions_tables.input,
        rules.reconstructions_parameters.input,
        rules.reconstructions_figures.input,
