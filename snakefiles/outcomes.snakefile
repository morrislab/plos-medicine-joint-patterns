"""
Analyzes outcomes in the patient groups.
"""

include: 'outcomes/age_time.snakefile'
include: 'outcomes/medications.snakefile'
include: 'outcomes/time_to_zero.snakefile'
include: 'outcomes/core_set.snakefile'



# Targets.

rule outcomes_tables:
    input:
        rules.outcomes_age_time_tables.input,
        rules.outcomes_medications_tables.input,
        rules.outcomes_time_to_zero_tables.input,
        rules.outcomes_core_set_tables.input



rule outcomes_parameters:
    input:
        rules.outcomes_age_time_parameters.input,
        rules.outcomes_medications_parameters.input,
        rules.outcomes_time_to_zero_parameters.input,
        rules.outcomes_core_set_parameters.input,



rule outcomes_figures:
    input:
        rules.outcomes_age_time_figures.input,
        rules.outcomes_medications_figures.input,
        rules.outcomes_time_to_zero_figures.input,
        rules.outcomes_core_set_figures.input



rule outcomes:
    input:
        rules.outcomes_tables.input,
        rules.outcomes_parameters.input,
        rules.outcomes_figures.input,
