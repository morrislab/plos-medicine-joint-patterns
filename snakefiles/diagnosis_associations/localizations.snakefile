"""
Associations with diagnoses, by localization.
"""

COHORTS = ['discovery']

ANALYSES = ['localizations', 'sublocalizations']

LOCALIZATIONS = ['limited', 'undifferentiated']

SUBLOCALIZATIONS = ['limited', 'partial', 'undifferentiated']



# Source clusters.

rule diagnosis_associations_localizations_discovery_clusters_localization_pattern:
    output:
        'tables/diagnosis_associations/discovery/clusters/localizations/{localization}.csv'
    input:
        'tables/localizations/discovery/final/l2.csv'
    shell:
        'head -n 1 {input} | cut -d, -f 1-2 > {output}; tail -n +2 {input} | awk /{wildcards.localization}/ | cut -d, -f 1-2 >> {output}'



rule diagnosis_associations_localizations_discovery_clusters_sublocalization_pattern:
    output:
        'tables/diagnosis_associations/discovery/clusters/sublocalizations/{sublocalization}.csv'
    input:
        'tables/sublocalizations/discovery/assignments.csv'
    shell:
        'head -n 1 {input} | cut -d, -f 1-2 > {output}; tail -n +2 {input} | awk /{wildcards.sublocalization}/ | cut -d, -f 1-2 >> {output}'



rule diagnosis_associations_localizations_clusters:
    input:
        expand(rules.diagnosis_associations_localizations_discovery_clusters_localization_pattern.output, localization=LOCALIZATIONS),
        expand(rules.diagnosis_associations_localizations_discovery_clusters_sublocalization_pattern.output, sublocalization=SUBLOCALIZATIONS)



rule diagnosis_associations_chisq_pattern:
    output:
        chisq='tables/diagnosis_associations/{cohort}/chisq/{analysis}/{localization}/chisq.csv',
        posthoc='tables/diagnosis_associations/{cohort}/chisq/{analysis}/{localization}/posthoc.csv',
        flag=touch('tables/diagnosis_associations/{cohort}/chisq/{analysis}/{localization}/comparisons.done')
    input:
        diagnoses='tables/diagnoses/discovery/merged.csv',
        clusters='tables/diagnosis_associations/discovery/clusters/{analysis}/{localization}.csv'
    log:
        'tables/diagnosis_associations/{cohort}/chisq/{analysis}/{localization}/comparisons.log'
    version:
        v('scripts/circos/associate_diagnoses_clusters.R')
    shell:
        'Rscript scripts/circos/associate_diagnoses_clusters.R --diagnosis-input {input.diagnoses} --cluster-input {input.clusters} --chisq-output {output.chisq} --posthoc-output {output.posthoc} 2>&1 | tee {log}'



rule diagnosis_associations_chisq:
    input:
        expand(rules.diagnosis_associations_chisq_pattern.output, cohort=COHORTS, analysis='localizations', localization=LOCALIZATIONS),
        expand(rules.diagnosis_associations_chisq_pattern.output, cohort=COHORTS, analysis='sublocalizations', localization=SUBLOCALIZATIONS)



# Targets.

rule diagnosis_associations_localizations_tables:
    input:
        rules.diagnosis_associations_localizations_clusters.input,
        rules.diagnosis_associations_chisq.input



rule diagnosis_associations_localizations_figures:
    input:



rule diagnosis_associations_localizations:
    input:
        rules.diagnosis_associations_localizations_tables.input,
        rules.diagnosis_associations_localizations_figures.input

