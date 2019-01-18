# Outcome analyses.

include: 'outcomes/dai_data.snakefile'
include: 'outcomes/age_time.snakefile'
include: 'outcomes/dai_lm.snakefile'
include: 'outcomes/fsr.snakefile'
include: 'outcomes/dai_associations.snakefile'
include: 'outcomes/medications.snakefile'
include: 'outcomes/site_gains.snakefile'
include: 'outcomes/time_to_zero.snakefile'



# Targets.

rule outcome_tables:
    input:
        rules.discovery_outcomes_time_to_zero_tables.input



rule outcome_figures:
    input:
        rules.discovery_outcomes_time_to_zero_figures.input



rule outcomes:
    input:
        rules.outcome_tables.input,
        rules.outcome_figures.input
