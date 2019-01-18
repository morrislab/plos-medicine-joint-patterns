"""
Time-to-zero analyses using proportional hazards models.
"""

# Time-to-zero analysis.

include: 'time_to_zero/discovery.snakefile'
include: 'time_to_zero/validation.snakefile'



# Targets.

rule outcomes_time_to_zero_tables:
    input:
        rules.outcomes_time_to_zero_discovery_tables.input,
        rules.outcomes_time_to_zero_validation_tables.input,



rule outcomes_time_to_zero_parameters:
    input:
        rules.outcomes_time_to_zero_discovery_parameters.input,
        rules.outcomes_time_to_zero_validation_parameters.input,



rule outcomes_time_to_zero_figures:
    input:
        rules.outcomes_time_to_zero_discovery_figures.input,
        rules.outcomes_time_to_zero_validation_figures.input,



rule outcomes_time_to_zero:
    input:
        rules.outcomes_time_to_zero_tables.input,
        rules.outcomes_time_to_zero_parameters.input,
        rules.outcomes_time_to_zero_figures.input,
