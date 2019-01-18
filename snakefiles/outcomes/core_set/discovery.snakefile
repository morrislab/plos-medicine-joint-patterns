"""
Associations with core set variables in the discovery cohort.
"""

DATA = 'inputs/outcomes/core_set/discovery/data.feather'
CLUSTERS = 'inputs/outcomes/core_set/discovery/clusters.csv'



# Link inputs.

rule outcomes_core_set_discovery_inputs_data:
    output: DATA
    input: 'outputs/data/discovery/core_set.feather'
    shell: LN



rule outcomes_core_set_discovery_inputs_clusters:
    output: CLUSTERS
    input: 'outputs/clusters/discovery.csv'
    shell: LN



rule outcomes_core_set_discovery_inputs:
    input:
        DATA,
        CLUSTERS,


# Generate data.

rule outcomes_core_set_discovery_data:
    output: 'tables/outcomes/core_set/discovery/data.feather'
    log: 'tables/outcomes/core_set/discovery/data.log'
    benchmark: 'tables/outcomes/core_set/discovery/data.txt'
    input:
        data=DATA,
        clusters=CLUSTERS,
    version: v('scripts/outcomes/core_set/filter_data.py')
    shell:
        'python scripts/outcomes/core_set/filter_data.py --data-input {input.data} --cluster-input {input.clusters} --output {output}' + LOG



# Identify associations.

rule outcomes_core_set_discovery_associations:
    output:
        continuous='tables/outcomes/core_set/discovery/associations/continuous.csv',
        categorical='tables/outcomes/core_set/discovery/associations/categorical.csv',
        flag=touch('tables/outcomes/core_set/discovery/associations/stats.done'),
    log: 'tables/outcomes/core_set/discovery/associations/stats.log'
    benchmark: 'tables/outcomes/core_set/discovery/associations/stats.txt'
    input: rules.outcomes_core_set_discovery_data.output
    version: v('scripts/outcomes/core_set/get_associations.R')
    shell:
        'Rscript scripts/outcomes/core_set/get_associations.R --input {input} --continuous-output {output.continuous} --categorical-output {output.categorical}' + LOG



rule outcomes_core_set_discovery_pairwise:
    output: 'tables/outcomes/core_set/discovery/associations/pairwise.csv'
    log: 'tables/outcomes/core_set/discovery/associations/pairwise.log'
    benchmark: 'tables/outcomes/core_set/discovery/associations/pairwise.txt'
    input: rules.outcomes_core_set_discovery_data.output
    version: v('scripts/outcomes/core_set/get_pairwise_associations.R')
    shell:
        'Rscript scripts/outcomes/core_set/get_pairwise_associations.R --input {input} --output {output}' + LOG



# Plot distributions of core set outcomes.

rule outcomes_core_set_discovery_fig:
    output: 'figures/outcomes/core_set/discovery.pdf'
    log: 'figures/outcomes/core_set/discovery.log'
    benchmark: 'figures/outcomes/core_set/discovery.txt'
    input: rules.outcomes_core_set_discovery_data.output
    params:
        width=6,
        height=6,
        trans=[
            'num_active_joints=log',
            'num_lrom_joints=log',
            'num_enthesitis_sites=log',
            'crp=log',
            'esr=log1p',
            'chaq=log1p'
        ],
        point_size=0.75,
    version: v('scripts/outcomes/core_set/plot_associations.R')
    shell:
        'Rscript scripts/outcomes/core_set/plot_associations.R --input {input} --output {output} --figure-width {params.width} --figure-height {params.height} --trans {params.trans} --point-size {params.point_size}' + LOG



# Targets.

rule outcomes_core_set_discovery_tables:
    input:
        rules.outcomes_core_set_discovery_data.output,
        rules.outcomes_core_set_discovery_associations.output,
        rules.outcomes_core_set_discovery_pairwise.output



rule outcomes_core_set_discovery_parameters:
    input:



rule outcomes_core_set_discovery_figures:
    input:
        rules.outcomes_core_set_discovery_fig.output,



rule outcomes_core_set_discovery:
    input:
        rules.outcomes_core_set_discovery_inputs.input,
        rules.outcomes_core_set_discovery_tables.input,
        rules.outcomes_core_set_discovery_parameters.input,
        rules.outcomes_core_set_discovery_figures.input,
