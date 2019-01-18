"""
Associations with core set outcomes.
"""

include: 'core_set/discovery.snakefile'



# Targets.

rule outcomes_core_set_tables:
    input:
        rules.outcomes_core_set_discovery_tables.input,



rule outcomes_core_set_parameters:
    input:
        rules.outcomes_core_set_discovery_parameters.input,



rule outcomes_core_set_figures:
    input:
        rules.outcomes_core_set_discovery_figures.input,



rule outcomes_core_set:
    input:
        rules.outcomes_core_set_tables.input,
        rules.outcomes_core_set_parameters.input,
        rules.outcomes_core_set_figures.input
