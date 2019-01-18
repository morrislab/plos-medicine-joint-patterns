"""
Analyzes crosstalk between patient groups on underlying factors.
"""

include: 'crosstalk/scores.snakefile'



# Targets.

rule crosstalk_tables:
    input:
        rules.crosstalk_scores_tables.input,



rule crosstalk_parameters:
    input:
        rules.crosstalk_scores_parameters.input,



rule crosstalk_figures:
    input:
        rules.crosstalk_scores_figures.input,



rule crosstalk:
    input:
        rules.crosstalk_tables.input,
        rules.crosstalk_parameters.input,
        rules.crosstalk_figures.input,
