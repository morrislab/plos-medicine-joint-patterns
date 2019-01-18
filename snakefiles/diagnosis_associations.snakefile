"""
Associations with diagnoses.
"""

DIAGNOSIS_INPUT = 'inputs/diagnosis_associations/diagnoses/{cohort}.csv'
CLUSTER_INPUT = 'inputs/diagnosis_associations/clusters/{cohort}.csv'

# Link inputs.

rule diagnosis_associations_inputs_diagnoses_pattern:
    output: DIAGNOSIS_INPUT
    input: 'outputs/diagnoses/{cohort}.csv'
    shell: LN



rule diagnosis_associations_inputs_clusters_pattern:
    output: CLUSTER_INPUT
    input: 'outputs/clusters/{cohort}.csv'
    shell: LN



rule diagnosis_associations_inputs:
    input:
        expand(rules.diagnosis_associations_inputs_diagnoses_pattern.output, cohort='discovery'),
        expand(rules.diagnosis_associations_inputs_clusters_pattern.output, cohort='discovery'),



# Associations with diagnoses.

rule diagnosis_associations_stats_pattern:
    output:
        chisq='tables/diagnosis_associations/{cohort}/chisq.csv',
        posthoc='tables/diagnosis_associations/{cohort}/posthoc.csv',
        flag=touch('tables/diagnosis_associations/{cohort}/comparisons.done')
    log: 'tables/diagnosis_associations/{cohort}/comparisons.log'
    benchmark: 'tables/diagnosis_associations/{cohort}/comparisons.txt'
    input:
        diagnoses=DIAGNOSIS_INPUT,
        clusters=CLUSTER_INPUT,
    version: v('scripts/circos/associate_diagnoses_clusters.R')
    shell:
        'Rscript scripts/circos/associate_diagnoses_clusters.R --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --chisq-output {output.chisq} --posthoc-output {output.posthoc}' + LOG



rule diagnosis_associations_stats:
    input:
        expand(rules.diagnosis_associations_stats_pattern.output, cohort='discovery')



# Get proportions.

rule diagnosis_associations_proportions_pattern:
    output: 'tables/diagnosis_associations/proportions/{cohort}.csv'
    log: 'tables/diagnosis_associations/proportions/{cohort}.log'
    benchmark: 'tables/diagnosis_associations/proportions/{cohort}.txt'
    input:
        diagnoses=DIAGNOSIS_INPUT,
        clusters=CLUSTER_INPUT,
    version: v('scripts/circos/get_proportions.py')
    shell:
        'python scripts/circos/get_proportions.py --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --output {output}' + LOG



rule diagnosis_associations_proportions:
    input:
        expand(rules.diagnosis_associations_proportions_pattern.output, cohort='discovery')



# Targets.

rule diagnosis_associations_tables:
    input:
        rules.diagnosis_associations_stats.input,
        rules.diagnosis_associations_proportions.input



rule diagnosis_associations_parameters:
    input:



rule diagnosis_associations_figures:
    input:



rule diagnosis_associations:
    input:
        rules.diagnosis_associations_inputs.input,
        rules.diagnosis_associations_tables.input,
        rules.diagnosis_associations_parameters.input,
        rules.diagnosis_associations_figures.input,
