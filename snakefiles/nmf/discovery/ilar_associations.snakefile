# Associations between patient groups and ILAR classifications.

rule discovery_class_comparisons_chisq_pattern:
    output:
        chisq='tables/discovery/ilar_associations/{subanalysis}/chisq.csv',
        posthoc='tables/discovery/ilar_associations/{subanalysis}/posthoc.csv',
        flag=touch('tables/discovery/ilar_associations/{subanalysis}/comparisons.done')
    log:
        'tables/discovery/ilar_associations/{subanalysis}/comparisons.log'
    benchmark:
        'tables/discovery/ilar_associations/{subanalysis}/comparisons.txt'
    input:
        diagnoses='tables/diagnoses/discovery/merged.csv',
        clusters='tables/discovery/clusters/{subanalysis}.csv'
    version:
        v('scripts/circos/associate_diagnoses_clusters.R')
    shell:
        'Rscript scripts/circos/associate_diagnoses_clusters.R --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --chisq-output {output.chisq} --posthoc-output {output.posthoc} 2>&1 | tee {log}'



rule discovery_class_comparisons_chisq:
    input:
        expand(rules.discovery_class_comparisons_chisq_pattern.output, subanalysis=['nx', 'full'])



# Generate data for associations for oligoarthritis persistent vs. extended.

rule discovery_class_comparisons_oligoarthritis_data_pattern:
    output:
        diagnoses='tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/diagnoses.csv',
        clusters='tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/clusters.csv',
        flag=touch('tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/data.done')
    log:
        'tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/data.log',
    benchmark:
        'tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/data.txt',
    input:
        diagnoses='tables/diagnoses/discovery/merged.csv',
        clusters='tables/discovery/clusters/{subanalysis}.csv'
    version:
        v('scripts/circos/prepare_oligoarthritis_data.py')
    shell:
        'python scripts/circos/prepare_oligoarthritis_data.py --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --diagnosis-output {output.diagnoses} --cluster-output {output.clusters} 2>&1 | tee {log}'



rule discovery_class_comparisons_oligoarthritis_data:
    input:
        expand(rules.discovery_class_comparisons_oligoarthritis_data_pattern.output, subanalysis=['full'])



# Test for associations between forms of oligoarthritis and patient groups.

rule discovery_class_comparisons_oligoarthritis_chisq_pattern:
    output:
        chisq='tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/chisq.csv',
        posthoc='tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/posthoc.csv',
        flag=touch('tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/comparisons.done')
    log:
        'tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/comparisons.log'
    benchmark:
        'tables/discovery/ilar_associations/{subanalysis}/oligoarthritis/comparisons.txt'
    input:
        rules.discovery_class_comparisons_oligoarthritis_data_pattern.output.flag,
        diagnoses=rules.discovery_class_comparisons_oligoarthritis_data_pattern.output.diagnoses,
        clusters=rules.discovery_class_comparisons_oligoarthritis_data_pattern.output.clusters
    version:
        v('scripts/circos/associate_diagnoses_clusters.R')
    shell:
        'Rscript scripts/circos/associate_diagnoses_clusters.R --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --chisq-output {output.chisq} --posthoc-output {output.posthoc} 2>&1 | tee {log}'



rule discovery_class_comparisons_oligoarthritis_chisq:
    input:
        expand(rules.discovery_class_comparisons_oligoarthritis_chisq_pattern.output, subanalysis=['full'])



# Targets.

rule discovery_class_comparisons_tables:
    input:
        rules.discovery_class_comparisons_chisq.input,
        rules.discovery_class_comparisons_oligoarthritis_data.input,
        rules.discovery_class_comparisons_oligoarthritis_chisq.input



rule discovery_class_comparisons:
    input:
        rules.discovery_class_comparisons_tables.input
