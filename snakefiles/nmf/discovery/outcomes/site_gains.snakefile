# Determines which patient groups tend to gain non-representative joints.

DISCOVERY_NMF_OUTCOMES_SITE_GAIN_BATCH_NUMS = list(
    range(1, 1 + config['discovery']['site_gains']['permutation_test'][
        'batches']))



# Determine which non-representative joints patients gain at future time
# points, by producing an output of indicators of patients x joints.

rule nmf_discovery_outcomes_site_gain_indicators:
    output:
        'tables/discovery/outcomes/site_gains/indicators.feather'
    input:
        clusters=rules.clusters_discovery_nx.output,
        representative_sites=rules.representative_sites_discovery_nx.output,
        sites='tables/discovery/data/joints.feather'
    params:
        visits=[2, 3, 4, 5, 6, 7, 8]
    version:
        v('scripts/outcomes/site_gains/get_nonrepresentative_site_gains.py')
    run:
        visits = ' '.join('--visit {}'.format(x) for x in params.visits)
        shell('python scripts/outcomes/site_gains/get_nonrepresentative_site_gains.py --cluster-input {input.clusters} --representative-site-input {input.representative_sites} --site-input {input.sites} --output {output} ' + visits)



rule nmf_discovery_outcomes_site_gain_probabilities:
    output:
        'tables/discovery/outcomes/site_gains/probabilities.csv'
    input:
        rules.nmf_discovery_outcomes_site_gain_indicators.output
    version:
        v('scripts/outcomes/site_gains/get_probabilities.py')
    shell:
        'python scripts/outcomes/site_gains/get_probabilities.py --input {input} --output {output}'



rule nmf_discovery_outcomes_site_gain_probability_figure:
    output:
        'figures/discovery/outcomes/site_gains/probabilities.pdf'
    input:
        probabilities=rules.nmf_discovery_outcomes_site_gain_probabilities.output,
        site_order='data/site_order.txt'
    params:
        figure_width=4.5,
        figure_height=8
    version:
        v('scripts/outcomes/site_gains/plot_probabilities.R')
    shell:
        'Rscript scripts/outcomes/site_gains/plot_probabilities.R --input {input.probabilities} --output {output} --site-order {input.site_order} --figure-width {params.figure_width} --figure-height {params.figure_height}'



# Run a permutation test on the individual cells.

rule nmf_discovery_outcomes_site_gain_ptest_seeds:
    output:
        expand(
            'tables/discovery/outcomes/site_gains/permutation_test/seeds/seed_{i}.txt',
            i=DISCOVERY_NMF_OUTCOMES_SITE_GAIN_BATCH_NUMS)
    params:
        batches=config['discovery']['site_gains']['permutation_test']['batches'],
        iterations_per_batch=config['discovery']['site_gains']['permutation_test']['iterations_per_batch'],
        prefix='tables/discovery/outcomes/site_gains/permutation_test/seeds/seed_'
    shell:
        'python scripts/general/generate_seeds.py --output-prefix {params.prefix} --jobs {params.batches} --iterations-per-job {params.iterations_per_batch}'



rule nmf_discovery_outcomes_site_gain_ptest_samples:
    output:
        'tables/discovery/outcomes/site_gains/permutation_test/samples/samples_{i}.feather'
    input:
        clusters=rules.clusters_discovery_nx.output,
        representative_sites=rules.representative_sites_discovery_nx.output,
        sites='tables/discovery/data/joints.feather',
        seedlist='tables/discovery/outcomes/site_gains/permutation_test/seeds/seed_{i}.txt'
    params:
        visits=[2, 3, 4, 5, 6, 7, 8]
    version:
        v('scripts/outcomes/site_gains/get_permutation_samples.py')
    run:
        visits = ' '.join('--visit {}'.format(x) for x in params.visits)
        shell(
            'python scripts/outcomes/site_gains/get_permutation_samples.py --cluster-input {input.clusters} --representative-site-input {input.representative_sites} --site-input {input.sites} --seedlist {input.seedlist} --output {output} '
            + visits)



rule nmf_discovery_outcomes_site_gain_ptest_merged_samples:
    output:
        'tables/discovery/outcomes/site_gains/permutation_test/samples/merged_samples.feather'
    input:
        expand(rules.nmf_discovery_outcomes_site_gain_ptest_samples.output, i=DISCOVERY_NMF_OUTCOMES_SITE_GAIN_BATCH_NUMS)
    version:
        v('scripts/outcomes/site_gains/merge_permutation_samples.py')
    run:
        inputs = ' '.join('--input {}'.format(x) for x in input)
        shell('python scripts/outcomes/site_gains/merge_permutation_samples.py ' + inputs + ' --output {output}')



# After permuting, determine which cells are overrepresented.

rule nmf_discovery_outcomes_site_gain_ptest_pvalues:
    output:
        'tables/discovery/outcomes/site_gains/permutation_test/p_values.csv'
    input:
        base=rules.nmf_discovery_outcomes_site_gain_probabilities.output,
        samples=rules.nmf_discovery_outcomes_site_gain_ptest_merged_samples.output
    version:
        v('scripts/outcomes/site_gains/get_p_values.py')
    shell:
        'python scripts/outcomes/site_gains/get_p_values.py --base-input {input.base} --sample-input {input.samples} --output {output}'



# Also try using logistic regression to determine which patient groups predict
# site gains.

rule nmf_discovery_outcomes_site_gains_lm:
    output:
        'tables/discovery/outcomes/site_gains/linear_regression/coefficients.csv'
    input:
        rules.nmf_discovery_outcomes_site_gain_indicators.output
    version:
        v('scripts/outcomes/site_gains/predict_cluster_gains.R')
    shell:
        'Rscript scripts/outcomes/site_gains/predict_cluster_gains.R --input {input} --output {output}'



# Targets.

rule nmf_discovery_joint_gain_tables:
    input:
        rules.nmf_discovery_outcomes_site_gain_indicators.output,
        rules.nmf_discovery_outcomes_site_gain_probabilities.output,
        rules.nmf_discovery_outcomes_site_gain_ptest_seeds.output,
        rules.nmf_discovery_outcomes_site_gain_ptest_merged_samples.input,
        rules.nmf_discovery_outcomes_site_gain_ptest_merged_samples.output,
        rules.nmf_discovery_outcomes_site_gain_ptest_pvalues.output,
        rules.nmf_discovery_outcomes_site_gains_lm.output



rule nmf_discovery_joint_gain_figures:
    input:
        rules.nmf_discovery_outcomes_site_gain_probability_figure.output



rule nmf_discovery_joint_gains:
    input:
        rules.nmf_discovery_joint_gain_tables.input,
        rules.nmf_discovery_joint_gain_figures.input