# Heat maps for sub-cohort assignments.

rule discovery_subcohort_trajectory_filtered:
    input:
        'tables/discovery/subcohorts/assignments_{n}.csv'
    output:
        'tables/discovery/subcohort_trajectories/filtered/data_{n}.csv'
    params:
        max_visit=config['discovery']['subcohorts']['max_visit']
    version:
        v('scripts/group_trajectories/filter_subcohort_visits.py')
    shell:
        'python scripts/group_trajectories/filter_subcohort_visits.py --input {input} --output {output} --max-visit {params.max_visit}'



rule discovery_subcohort_trajectory_data:
    input:
        rules.discovery_subcohort_trajectory_filtered.output
    output:
        'tables/discovery/subcohort_trajectories/filtered/data_{n}.csv'
    version:
        v('scripts/group_trajectories/get_heatmap_data.py')
    shell:
        'python scripts/group_trajectories/get_heatmap_data.py --input {input} --output {output}'



# Targets.

rule discovery_subcohort_trajectory_tables:
    input:
        expand(rules.discovery_subcohort_trajectory_filtered.output, n=config['discovery']['subcohorts']['n']),
        expand(rules.discovery_subcohort_trajectory_data.output, n=config['discovery']['subcohorts']['n'])



rule discovery_subcohort_trajectory_figures:
    input:



rule discovery_subcohort_trajectories:
    input:
        rules.discovery_subcohort_trajectory_tables.input,
        rules.discovery_subcohort_trajectory_figures.input
