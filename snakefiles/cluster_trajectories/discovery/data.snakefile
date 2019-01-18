"""
Generates trajectory analysis data for the discovery cohort.
"""

ANALYSES = ['base', 'localizations']

PARAMS = config.cluster_trajectories.discovery

MAX_VISIT = PARAMS.max_visit

DATA = 'inputs/cluster_trajectories/discovery/joints.feather'
PARAMETERS = 'inputs/cluster_trajectories/discovery/scaled/parameters/{level}.csv'
PARAMETERS_L1 = expand(PARAMETERS, level='l1')
PARAMETERS_L2 = expand(PARAMETERS, level='l2')
MODEL = 'inputs/cluster_trajectories/discovery/models/{level}.pkl'
MODEL_L1 = expand(MODEL, level='l1')
MODEL_L2 = expand(MODEL, level='l2')
BASELINE_CLUSTERS = 'inputs/cluster_trajectories/discovery/clusters/baseline.csv'
BASELINE_LOCALIZATIONS = 'inputs/cluster_trajectories/discovery/localizations/baseline.csv'



# Link inputs.

rule cluster_trajectories_discovery_data_inputs_filtered:
    output: DATA
    input: 'outputs/data/discovery/filtered.feather'
    shell: LN



rule cluster_trajectories_discovery_data_inputs_parameters_pattern:
    output: PARAMETERS
    input: 'outputs/nmf/discovery/{level}/scaled/parameters.csv'
    shell: LN



rule cluster_trajectories_discovery_data_inputs_models_pattern:
    output: MODEL
    input: 'outputs/nmf/discovery/{level}/model/model.pkl'
    shell: LN



rule cluster_trajectories_discovery_data_inputs_clusters:
    output: BASELINE_CLUSTERS
    input: 'outputs/clusters/discovery.csv'
    shell: LN



rule cluster_trajectories_discovery_data_inputs_localizations:
    output: BASELINE_LOCALIZATIONS
    input: 'outputs/localizations/unified/discovery.csv'
    shell: LN



rule cluster_trajectories_discovery_data_inputs:
    input:
        rules.cluster_trajectories_discovery_data_inputs_filtered.output,
        expand(rules.cluster_trajectories_discovery_data_inputs_parameters_pattern.output, level=['l1', 'l2']),
        expand(rules.cluster_trajectories_discovery_data_inputs_models_pattern.output, level=['l1', 'l2']),
        rules.cluster_trajectories_discovery_data_inputs_clusters.output,
        rules.cluster_trajectories_discovery_data_inputs_localizations.output,



# For each visit, calculate scores.

rule cluster_trajectories_discovery_scores:
    output: 'tables/cluster_trajectories/discovery/scores.csv'
    log: 'tables/cluster_trajectories/discovery/scores.log'
    benchmark: 'tables/cluster_trajectories/discovery/scores.txt'
    input:
        data=DATA,
        parameters_l1=PARAMETERS_L1,
        parameters_l2=PARAMETERS_L2,
        model_l1=MODEL_L1,
        model_l2=MODEL_L2,
    params:
        max_visit=MAX_VISIT,
    version: v('scripts/group_trajectories/get_score_trajectories_all.py')
    shell:
        'python scripts/group_trajectories/get_score_trajectories_all.py --joint-data-input {input.data} --scaling-parameter-input {input.parameters_l1} --scaling-parameter-input {input.parameters_l2} --nmf-model-input {input.model_l1} --nmf-model-input {input.model_l2} --output {output} --max-visit {params.max_visit}' + LOG



# For each visit, determine patient group assignments.

rule cluster_trajectories_discovery_clusters_base:
    output: 'tables/cluster_trajectories/discovery/clusters/base.csv'
    log: 'tables/cluster_trajectories/discovery/clusters/base.log'
    benchmark: 'tables/cluster_trajectories/discovery/clusters/base.txt'
    input:
        baseline_clusters=BASELINE_CLUSTERS,
        scores=rules.cluster_trajectories_discovery_scores.output
    version: v('scripts/group_trajectories/get_group_trajectories.py')
    shell:
        'python scripts/group_trajectories/get_group_trajectories.py --baseline-cluster-input {input.baseline_clusters} --score-input {input.scores} --output {output}' + LOG



rule cluster_trajectories_discovery_clusters_localizations:
    output: 'tables/cluster_trajectories/discovery/clusters/localizations.csv'
    log: 'tables/cluster_trajectories/discovery/clusters/localizations.log'
    benchmark: 'tables/cluster_trajectories/discovery/clusters/localizations.txt'
    input:
        baseline_clusters=BASELINE_LOCALIZATIONS,
        scores=rules.cluster_trajectories_discovery_scores.output
    version: v('scripts/group_trajectories/get_group_trajectories.py')
    shell:
        'python scripts/group_trajectories/get_group_trajectories.py --baseline-cluster-input {input.baseline_clusters} --score-input {input.scores} --output {output}' + LOG



rule cluster_trajectories_discovery_groups:
    input:
        expand('tables/cluster_trajectories/discovery/clusters/{analysis}.csv', analysis=ANALYSES)



# Targets.

rule cluster_trajectories_discovery_data_tables:
    input:
        rules.cluster_trajectories_discovery_scores.output,
        rules.cluster_trajectories_discovery_groups.input



rule cluster_trajectories_discovery_data_parameters:
    input:



rule cluster_trajectories_discovery_data_figures:
    input:



rule cluster_trajectories_discovery_data:
    input:
        rules.cluster_trajectories_discovery_data_inputs.input,
        rules.cluster_trajectories_discovery_data_tables.input,
        rules.cluster_trajectories_discovery_data_parameters.input,
        rules.cluster_trajectories_discovery_data_figures.input,
