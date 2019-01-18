# Subcohort trajectories.

rule nmf_discovery_subcohort_trajectory_trajectories:
    output:
        'tables/discovery/nmf_trajectories/subcohorts/trajectories.csv'
    input:
        clusters=rules.clusters_discovery_nx.output,
        subcohorts=expand('tables/discovery/subcohorts/filtered/assignments_{x}.csv', x=config['discovery']['clusters']['n'])
    params:
        visits=[2, 3, 4, 5, 6, 7, 8]
    version:
        v('scripts/group_trajectories/get_subcohort_trajectories.py')
    run:
        visits=' '.join('--visit {}'.format(x) for x in params.visits)
        shell('python scripts/group_trajectories/get_subcohort_trajectories.py --cluster-input {input.clusters} --subcohort-input {input.subcohorts} --output {output} ' + visits)



rule nmf_discovery_subcohort_trajectory_data:
    output:
        'tables/discovery/nmf_trajectories/subcohorts/data_any.csv'
    input:
        rules.nmf_discovery_subcohort_trajectory_trajectories.output
    version:
        v('scripts/group_trajectories/get_heatmap_data_any.py')
    shell:
        'python scripts/group_trajectories/get_heatmap_data_any.py --input {input} --output {output}'



DISCOVERY_NMF_SUBCOHORT_TRAJECTORY_BATCHES = [k + 1 for k in range(config['discovery']['subcohort_trajectories']['permutation_test']['batches'])]



rule nmf_discovery_subcohort_trajectory_stats_seeds:
    output:
        seeds=expand('tables/discovery/nmf_trajectories/subcohorts/permutation_test/seeds/seeds_{batch}.txt', batch=DISCOVERY_NMF_SUBCOHORT_TRAJECTORY_BATCHES),
        flag=touch('tables/discovery/nmf_trajectories/subcohorts/permutation_test/seeds/seeds.done')
    params:
        batches=config['discovery']['subcohort_trajectories']['permutation_test']['batches'],
        permutations_per_batch=config['discovery']['subcohort_trajectories']['permutation_test']['permutations_per_batch'],
        seed=config['discovery']['subcohort_trajectories']['permutation_test']['seed'],
        prefix='tables/discovery/nmf_trajectories/subcohorts/permutation_test/seeds/seeds_'
    version:
        v('scripts/general/generate_seeds.py')
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.prefix} --jobs {params.batches} --iterations-per-job {params.permutations_per_batch} --seed {params.seed}'



rule nmf_discovery_subcohort_trajectory_stats_sample_pattern:
    input:
        data=rules.nmf_discovery_subcohort_trajectory_trajectories.output,
        seedlist='tables/discovery/nmf_trajectories/subcohorts/permutation_test/seeds/seeds_{batch}.txt',
        flags=rules.cluster_trajectories_discovery_heatmap_any_stats_seeds.output.flag
    output:
        'tables/discovery/nmf_trajectories/subcohorts/permutation_test/samples/samples_{batch}.feather'
    version:
        v('scripts/group_trajectories/get_permutation_samples_any.py')
    shell:
        'python scripts/group_trajectories/get_permutation_samples_any.py --input {input.data} --seedlist {input.seedlist} --output {output}'



rule nmf_discovery_subcohort_trajectory_stats_samples:
    input:
        expand(rules.nmf_discovery_subcohort_trajectory_stats_sample_pattern.output, batch=DISCOVERY_NMF_SUBCOHORT_TRAJECTORY_BATCHES)



rule nmf_discovery_subcohort_trajectory_stats_concatenated:
    output:
        'tables/discovery/nmf_trajectories/subcohorts/permutation_test/concatenated/samples.feather'
    input:
        rules.nmf_discovery_subcohort_trajectory_stats_samples.input
    version:
        v('scripts/group_trajectories/concatenate_permutation_samples_any.py')
    run:
        inputs = ' '.join('--input {}'.format(x) for x in input)
        shell('python scripts/group_trajectories/concatenate_permutation_samples_any.py  --output {output} ' + inputs)



rule nmf_discovery_subcohort_trajectory_stats:
    output:
        'tables/discovery/nmf_trajectories/subcohorts/permutation_test/p.csv'
    input:
        probabilities='tables/discovery/nmf_trajectories/subcohorts/data_any.csv',
        concatenated=rules.nmf_discovery_subcohort_trajectory_stats_concatenated.output
    version:
        v('scripts/group_trajectories/get_permutation_p_values.py')
    shell:
        'python scripts/group_trajectories/get_permutation_p_values.py --probability-input {input.probabilities} --sample-input {input.concatenated} --output {output}'



rule nmf_discovery_subcohort_trajectory_figure:
    input:
        data='tables/discovery/nmf_trajectories/subcohorts/data_any.csv',
        stats=rules.nmf_discovery_subcohort_trajectory_stats.output
    output:
        'figures/discovery/nmf_trajectories/subcohorts/transitions.pdf'
    params:
        figure_width=4.5,
        figure_height=4.5,
        max_size=4
    version:
        v('scripts/group_trajectories/plot_heatmaps_any.R')
    shell:
        'Rscript scripts/group_trajectories/plot_heatmaps_any.R --input {input.data} --stats-input {input.stats} --output {output} --figure-width {params.figure_width} --figure-height {params.figure_height} --colour-scale --max-size {params.max_size}'



# Targets.

rule nmf_discovery_subcohort_trajectory_tables:
    input:
        rules.nmf_discovery_subcohort_trajectory_trajectories.output,
        rules.nmf_discovery_subcohort_trajectory_data.output,
        rules.nmf_discovery_subcohort_trajectory_stats_seeds.output,
        rules.nmf_discovery_subcohort_trajectory_stats_samples.input,
        rules.nmf_discovery_subcohort_trajectory_stats_concatenated.output,
        rules.nmf_discovery_subcohort_trajectory_stats.output



rule nmf_discovery_subcohort_trajectory_figures:
    input:
        rules.nmf_discovery_subcohort_trajectory_figure.output



rule nmf_discovery_subcohort_trajectories:
    input:
        rules.nmf_discovery_subcohort_trajectory_tables.input,
        rules.nmf_discovery_subcohort_trajectory_figures.input