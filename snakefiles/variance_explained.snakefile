"""
Calculates variance explained.
"""

include: 'variance_explained/discovery.snakefile'
include: 'variance_explained/validation.snakefile'



# Targets.

rule variance_explained_tables:
    input:
        rules.variance_explained_discovery_tables.input,
        rules.variance_explained_validation_tables.input,



rule variance_explained_parameters:
    input:
        rules.variance_explained_discovery_parameters.input,
        rules.variance_explained_validation_parameters.input,



rule variance_explained_figures:
    input:
        rules.variance_explained_discovery_figures.input,
        rules.variance_explained_validation_figures.input,



rule variance_explained:
    input:
        rules.variance_explained_tables.input,
        rules.variance_explained_parameters.input,
        rules.variance_explained_figures.input,
