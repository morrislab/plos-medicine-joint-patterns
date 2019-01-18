# Calculates the time to zero site involvement.

ANALYSES = ['base', 'localized']



rule nmf_discovery_trajectories_time_to_zero_data_pattern:
    output:
        'tables/discovery/nmf_trajectories/time_to_zero/data/{analysis}.feather'
    input:
        'tables/discovery/nmf_trajectories/clusters/{analysis}.csv'
    version:
        v('scripts/group_trajectories/get_time_to_zero.py')
    shell:
        'python scripts/group_trajectories/get_time_to_zero.py --input {input} --output {output}'



rule nmf_discovery_trajectories_time_to_zero_data:
    input:
        expand(rules.nmf_discovery_trajectories_time_to_zero_data_pattern.output, analysis=ANALYSES)



rule nmf_discovery_trajectories_time_to_zero_summary_pattern:
    output:
        'tables/discovery/nmf_trajectories/time_to_zero/summary/{analysis}.csv'
    input:
        rules.nmf_discovery_trajectories_time_to_zero_data_pattern.output
    version:
        v('scripts/group_trajectories/summarize_time_to_zero.R')
    shell:
        'Rscript scripts/group_trajectories/summarize_time_to_zero.R --input {input} --output {output}'



rule nmf_discovery_trajectories_time_to_zero_summary:
    input:
        expand(rules.nmf_discovery_trajectories_time_to_zero_summary_pattern.output, analysis=ANALYSES)



# Targets.

rule nmf_discovery_trajectories_time_to_zero_tables:
    input:
        rules.nmf_discovery_trajectories_time_to_zero_data.input,
        rules.nmf_discovery_trajectories_time_to_zero_summary.input



rule nmf_discovery_trajectories_time_to_zero:
    input:
        rules.nmf_discovery_trajectories_time_to_zero_tables.input