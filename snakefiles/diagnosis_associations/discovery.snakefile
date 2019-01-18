# Associations with diagnoses in the discovery cohort.

rule diagnosis_associations_discovery_chisq_pattern:
    output:
        chisq='tables/ilar_associations/discovery/{subanalysis}/chisq.csv',
        posthoc='tables/ilar_associations/discovery/{subanalysis}/posthoc.csv',
        flag=touch('tables/ilar_associations/discovery/{subanalysis}/comparisons.done')
    input:
        diagnoses='tables/diagnoses/discovery/merged.csv',
        clusters='tables/discovery/clusters/{subanalysis}.csv'
    version:
        v('scripts/circos/associate_diagnoses_clusters.R')
    shell:
        'Rscript scripts/circos/associate_diagnoses_clusters.R --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --chisq-output {output.chisq} --posthoc-output {output.posthoc}'



rule diagnosis_associations_discovery_chisq:
    input:
        expand(rules.diagnosis_associations_discovery_chisq_pattern.output, subanalysis='full')



rule diagnosis_associations_discovery_proportions:
    output:
        'tables/ilar_associations/discovery/proportions.csv'
    input:
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        clusters=rules.clusters_discovery_full.output
    version:
        v('scripts/circos/get_proportions.py')
    shell:
        'python scripts/circos/get_proportions.py --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --output {output}'



# Targets.

rule diagnosis_associations_discovery_tables:
    input:
        rules.diagnosis_associations_discovery_chisq.input,
        rules.diagnosis_associations_discovery_proportions.output



rule diagnosis_associations_discovery:
    input:
        rules.diagnosis_associations_discovery_tables.input
