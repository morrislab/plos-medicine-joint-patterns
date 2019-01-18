"""
Generates base colours for the homunculi.
"""

DATA_INPUT = 'inputs/homunculi/data/{cohort}.csv'
CLUSTER_INPUT = 'inputs/homunculi/clusters/{cohort}.csv'
JOINT_POSITIONS = 'data/homunculus_positions/homunculus_positions.xlsx',



# Link inputs.

rule homunculi_inputs_data_pattern:
    output: DATA_INPUT
    input: 'outputs/data/{cohort}/joints.csv'
    shell: LN



rule homunculi_inputs_data:
    input:
        expand(rules.homunculi_inputs_data_pattern.output, cohort='discovery'),



rule homunculi_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/{cohort}.csv'
    shell: LN



rule homunculi_inputs_clusters:
    input:
        expand(rules.homunculi_inputs_clusters_pattern.output, cohort='discovery'),



rule homunculi_inputs:
    input:
        rules.homunculi_inputs_data.input,
        rules.homunculi_inputs_clusters.input,



# Calculate frequencies.

rule homunculi_frequencies_pattern:
    output: 'tables/homunculi/frequencies/{cohort}.csv'
    log: 'tables/homunculi/frequencies/{cohort}.log'
    benchmark: 'tables/homunculi/frequencies/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
    version: v('scripts/homunculi/get_frequencies.py')
    shell:
        'python scripts/homunculi/get_frequencies.py --data-input {input.data} --cluster-input {input.clusters} --output {output}' + LOG



rule homunculi_frequencies:
    input:
        expand(rules.homunculi_frequencies_pattern.output, cohort='discovery'),



# Plot frequencies.

rule homunculi_fig_pattern:
    output: 'figures/homunculi/{cohort}.pdf'
    log: 'figures/homunculi/{cohort}.log'
    benchmark: 'figures/homunculi/{cohort}.txt'
    input:
        data=DATA_INPUT,
        clusters=CLUSTER_INPUT,
        joint_positions=JOINT_POSITIONS,
    params:
        width=7,
        height=7,
        max_point_size=2,
        trans='identity',
        clip=0.5,
        option=VIRIDIS_PALETTE,
    version: v('scripts/homunculi/plot_signature_homunculi.R')
    shell:
        'Rscript scripts/homunculi/plot_signature_homunculi.R --input {input.data} --clusters {input.clusters} --joint-positions {input.joint_positions} --output {output} --figure-width {params.width} --figure-height {params.height} --max-point-size {params.max_point_size} --trans {params.trans} --clip {params.clip} --mirror --option {params.option}' + LOG



rule homunculi_fig:
    input:
        expand(rules.homunculi_fig_pattern.output, cohort='discovery'),



# Link outputs.

rule homunculi_outputs_pattern:
    output: 'outputs/homunculi/frequencies/{cohort}.csv'
    input: rules.homunculi_frequencies_pattern.output
    shell: LN



rule homunculi_outputs:
    input:
        expand(rules.homunculi_outputs_pattern.output, cohort=COHORTS),



# Targets.

rule homunculi_tables:
    input:
        rules.homunculi_frequencies.input,



rule homunculi_parameters:
    input:



rule homunculi_figures:
    input:
        rules.homunculi_fig.input,



rule homunculi:
    input:
        rules.homunculi_inputs.input,
        rules.homunculi_tables.input,
        rules.homunculi_parameters.input,
        rules.homunculi_figures.input,
        rules.homunculi_outputs.input,
