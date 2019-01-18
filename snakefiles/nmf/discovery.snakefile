"""
NMF on the discovery cohort.
"""

include: 'discovery/l1.snakefile'
include: 'discovery/l2.snakefile'
# include: 'discovery/ilar_associations.snakefile'



# Link inputs.

rule nmf_discovery_inputs:
    input:



# Link outputs.

rule nmf_discovery_outputs:
    input:
        rules.nmf_discovery_l1_outputs.input,
        rules.nmf_discovery_l2_outputs.input,



# Targets.

rule nmf_discovery_tables:
    input:
        rules.nmf_discovery_l1_tables.input,
        rules.nmf_discovery_l2_tables.input,
        # rules.nmf_discovery_ilar_associations_tables.input,



rule nmf_discovery_parameters:
    input:
        rules.nmf_discovery_l1_parameters.input,
        rules.nmf_discovery_l2_parameters.input,
        # rules.nmf_discovery_ilar_associations_parameters.input,



rule nmf_discovery_figures:
    input:
        rules.nmf_discovery_l1_figures.input,
        rules.nmf_discovery_l2_figures.input,
        # rules.nmf_discovery_ilar_associations_figures.input,



rule nmf_discovery:
    input:
        rules.nmf_discovery_inputs.input,
        rules.nmf_discovery_tables.input,
        rules.nmf_discovery_parameters.input,
        rules.nmf_discovery_figures.input,
        rules.nmf_discovery_outputs.input,
