"""
Co-occurrences in the clusters and ILAR categories.
"""

DIAGNOSES = ['systemic_arthritis', 'oligoarthritis', 'rf_negative_polyarthritis', 'rf_positive_polyarthritis', 'enthesitis_related_arthritis', 'psoriatic_arthritis', 'undifferentiated_arthritis']

CLUSTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'G']



rule co_occurrences_clusters_data_diagnosis_pattern:
    output:
        expand('tables/co_occurrences_clusters/{cohort}/data/diagnoses/{diagnosis}.csv', cohort='{cohort}', diagnosis=DIAGNOSES),
        flag=touch('tables/co_occurrences_clusters/{cohort}/data/diagnoses.done'),
    log: 'tables/co_occurrences_clusters/{cohort}/data/diagnoses.log'
    benchmark: 'tables/co_occurrences_clusters/{cohort}/data/diagnoses.txt'
    input:
        rules.data_discovery_split.output.flag,
        data=rules.data_discovery_split.output.data[0],
        diagnoses='tables/diagnoses/discovery/merged.csv',
    params:
        output_prefix='tables/co_occurrences_clusters/{cohort}/data/diagnoses',
    version: v('scripts/co_occurrences_clusters/get_data_diagnoses.py')
    shell:
        'python scripts/co_occurrences_clusters/get_data_diagnoses.py --data-input {input.data} --diagnosis-input {input.diagnoses} --output-prefix {params.output_prefix} 2>&1 | tee {log}'



rule co_occurrences_clusters_data_clusters_pattern:
    output:
        expand('tables/co_occurrences_clusters/{cohort}/data/clusters/{cluster}.csv', cohort='{cohort}', cluster=CLUSTERS),
        flag=touch('tables/co_occurrences_clusters/{cohort}/data/clusters.done'),
    log: 'tables/co_occurrences_clusters/{cohort}/data/clusters.log'
    benchmark: 'tables/co_occurrences_clusters/{cohort}/data/clusters.txt'
    input:
        rules.data_discovery_split.output.flag,
        data=rules.data_discovery_split.output.data[0],
        clusters='tables/clusters/discovery/levels/l2.csv'
    params:
        output_prefix='tables/co_occurrences_clusters/{cohort}/data/clusters',
    version: v('scripts/co_occurrences_clusters/get_data_clusters.py')
    shell:
        'python scripts/co_occurrences_clusters/get_data_clusters.py --data-input {input.data} --cluster-input {input.clusters} --output-prefix {params.output_prefix} 2>&1 | tee {log}'



rule co_occurrences_clusters_data:
    input:
        expand(rules.co_occurrences_clusters_data_diagnosis_pattern.output, cohort='discovery'),
        expand(rules.co_occurrences_clusters_data_clusters_pattern.output, cohort='discovery'),



# Stats.

rule co_occurrences_clusters_z_statistics_diagnosis_pattern:
    output: 'tables/co_occurrences_clusters/z/statistics/{cohort}/diagnoses/{diagnosis}.feather'
    log: 'tables/co_occurrences_clusters/z/statistics/{cohort}/diagnoses/{diagnosis}.log'
    benchmark: 'tables/co_occurrences_clusters/z/statistics/{cohort}/diagnoses/{diagnosis}.txt'
    input:
        'tables/co_occurrences_clusters/{cohort}/data/diagnoses.done',
        data='tables/co_occurrences_clusters/{cohort}/data/diagnoses/{diagnosis}.csv',
    params:
        c=1,
    version: v('scripts/cooccurrence/z/get_stats.py')
    shell:
        'python scripts/cooccurrence/z/get_stats.py --input {input.data} --output {output} --c {params.c} 2>&1 | tee {log}'



rule co_occurrences_clusters_z_statistics_cluster_pattern:
    output: 'tables/co_occurrences_clusters/z/statistics/{cohort}/clusters/{cluster}.feather'
    log: 'tables/co_occurrences_clusters/z/statistics/{cohort}/clusters/{cluster}.log'
    benchmark: 'tables/co_occurrences_clusters/z/statistics/{cohort}/clusters/{cluster}.txt'
    input:
        'tables/co_occurrences_clusters/{cohort}/data/clusters.done',
        data='tables/co_occurrences_clusters/{cohort}/data/clusters/{cluster}.csv',
    params:
        c=1,
    version: v('scripts/cooccurrence/z/get_stats.py')
    shell:
        'python scripts/cooccurrence/z/get_stats.py --input {input.data} --output {output} --c {params.c} 2>&1 | tee {log}'




rule co_occurrences_clusters_z_statistics:
    input:
        expand(rules.co_occurrences_clusters_z_statistics_diagnosis_pattern.output, cohort='discovery', diagnosis=DIAGNOSES),
        expand(rules.co_occurrences_clusters_z_statistics_cluster_pattern.output, cohort='discovery', cluster=CLUSTERS),



# Conduct chi-squared tests to determine which site types display significant
# same-side or opposite-side skewing.

rule co_occurrences_clusters_z_chisq_diagnosis_pattern:
    output: 'tables/co_occurrences_clusters/z/chisq/{cohort}/diagnoses/{diagnosis}.csv'
    log: 'tables/co_occurrences_clusters/z/chisq/{cohort}/diagnoses/{diagnosis}.log'
    benchmark: 'tables/co_occurrences_clusters/z/chisq/{cohort}/diagnoses/{diagnosis}.txt'
    input: 'tables/co_occurrences_clusters/z/statistics/{cohort}/diagnoses/{diagnosis}.feather'
    version: v('scripts/cooccurrence/z/do_chisq.R')
    shell:
        'Rscript scripts/cooccurrence/z/do_chisq.R --input {input} --output {output} 2>&1 | tee {log}'



rule co_occurrences_clusters_z_chisq_cluster_pattern:
    output: 'tables/co_occurrences_clusters/z/chisq/{cohort}/clusters/{cluster}.csv'
    log: 'tables/co_occurrences_clusters/z/chisq/{cohort}/clusters/{cluster}.log'
    benchmark: 'tables/co_occurrences_clusters/z/chisq/{cohort}/clusters/{cluster}.txt'
    input: 'tables/co_occurrences_clusters/z/statistics/{cohort}/clusters/{cluster}.feather'
    version: v('scripts/cooccurrence/z/do_chisq.R')
    shell:
        'Rscript scripts/cooccurrence/z/do_chisq.R --input {input} --output {output} 2>&1 | tee {log}'



rule co_occurrences_clusters_z_chisq:
    input:
        expand(rules.co_occurrences_clusters_z_chisq_diagnosis_pattern.output, cohort='discovery', diagnosis=DIAGNOSES),
        expand(rules.co_occurrences_clusters_z_chisq_cluster_pattern.output, cohort='discovery', cluster=CLUSTERS),



# Plot figures.

rule co_occurrences_clusters_z_fig_diagnosis_pattern:
    output: 'figures/co_occurrences_clusters/z/{cohort}/diagnoses/{diagnosis}.pdf'
    log: 'figures/co_occurrences_clusters/z/{cohort}/diagnoses/{diagnosis}.log'
    benchmark: 'figures/co_occurrences_clusters/z/{cohort}/diagnoses/{diagnosis}.txt'
    input:
        data='tables/co_occurrences_clusters/z/statistics/{cohort}/diagnoses/{diagnosis}.feather',
        statistics=rules.co_occurrences_clusters_z_chisq_diagnosis_pattern.output,
        site_order='data/site_order_deltas.txt'
    params:
        width=6,
        height=6,
        percentile_threshold=5e-15
    version:
        v('scripts/cooccurrence/z/plot_matrix.R')
    shell:
        'Rscript scripts/cooccurrence/z/plot_matrix.R --data-input {input.data} --statistics-input {input.statistics} --site-order-input {input.site_order} --output {output} --width {params.width} --height {params.height} --percentile-threshold {params.percentile_threshold} 2>&1 | tee {log}'



rule co_occurrences_clusters_z_fig_cluster_pattern:
    output: 'figures/co_occurrences_clusters/z/{cohort}/clusters/{cluster}.pdf'
    log: 'figures/co_occurrences_clusters/z/{cohort}/clusters/{cluster}.log'
    benchmark: 'figures/co_occurrences_clusters/z/{cohort}/clusters/{cluster}.txt'
    input:
        data='tables/co_occurrences_clusters/z/statistics/{cohort}/clusters/{cluster}.feather',
        statistics=rules.co_occurrences_clusters_z_chisq_cluster_pattern.output,
        site_order='data/site_order_deltas.txt'
    params:
        width=6,
        height=6,
        percentile_threshold=5e-15
    version:
        v('scripts/cooccurrence/z/plot_matrix.R')
    shell:
        'Rscript scripts/cooccurrence/z/plot_matrix.R --data-input {input.data} --statistics-input {input.statistics} --site-order-input {input.site_order} --output {output} --width {params.width} --height {params.height} --percentile-threshold {params.percentile_threshold} 2>&1 | tee {log}'



rule co_occurrences_clusters_z_fig:
    input:
        expand(rules.co_occurrences_clusters_z_fig_diagnosis_pattern.output, cohort='discovery', diagnosis=DIAGNOSES),
        expand(rules.co_occurrences_clusters_z_fig_cluster_pattern.output, cohort='discovery', cluster=CLUSTERS),
    


# Targets.

rule co_occurrences_clusters_tables:
    input:
        rules.co_occurrences_clusters_data.input,
        rules.co_occurrences_clusters_z_statistics.input,
        rules.co_occurrences_clusters_z_chisq.input,



rule co_occurrences_clusters_figures:
    input:
        rules.co_occurrences_clusters_z_fig.input,



rule co_occurrences_clusters:
    input:
        rules.co_occurrences_clusters_tables.input,
        rules.co_occurrences_clusters_figures.input,