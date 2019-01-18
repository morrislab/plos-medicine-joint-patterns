"""
Generates data files.
"""

# Rules for generating data files.

include: 'data/discovery.snakefile'
include: 'data/validation.snakefile'
include: 'data/subject_ids.snakefile'
# include: 'data/paper.snakefile'
include: 'data/demographics.snakefile'



# Link outputs.

rule data_outputs:
    input:
        rules.data_discovery_outputs.input,
        rules.data_validation_outputs.input,
        rules.data_subject_ids_outputs.input,



# Targets.

rule data_figures:
    input:
        rules.data_discovery_figures.input,
        rules.data_validation_figures.input,
        rules.data_subject_ids_figures.input,
        rules.data_demographics_figures.input,
        # rules.data_subject_ids_figures.input,



rule data_parameters:
    input:
        rules.data_discovery_parameters.input,
        rules.data_validation_parameters.input,
        rules.data_subject_ids_parameters.input,
        rules.data_demographics_parameters.input,



rule data_tables:
    input:
        rules.data_discovery_tables.input,
        rules.data_validation_tables.input,
        rules.data_subject_ids_tables.input,
        # rules.data_paper_tables.input,
        rules.data_demographics_tables.input,



rule data:
    input:
        rules.data_figures.input,
        rules.data_parameters.input,
        rules.data_tables.input,
        rules.data_outputs.input,
