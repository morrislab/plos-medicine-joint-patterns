# Data for regression analyses for the disease activity indicator.

VISITS = [2, 3]

rule discovery_outcomes_dai_data_cluster_diagnosis_pattern:
    output:
        'tables/discovery/outcomes/dai/data/cluster_diagnoses/visit_{visit}.feather'
    input:
        clusters=rules.clusters_discovery_full.output,
        localizations=rules.clusters_discovery_localizations.output,
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        dai_scores=rules.data_discovery_dai_projections.output,
        medications=rules.data_discovery_medications.output,
        age_time=rules.data_discovery_basics.output,
        patient_filter=rules.data_discovery_filtered.output.filter,
        flags=rules.data_discovery_filtered.output.flag
    params:
        ignore=['nsaid_status', 'diagnosis_6_months']
    version:
        v('scripts/dai_associations/combine_data.py')
    run:
        ignore = ' '.join('--ignore {}'.format(x) for x in params.ignore)
        shell('python scripts/dai_associations/combine_data.py --filter-input {input.patient_filter} --cluster-input {input.clusters} --localization-input {input.localizations} --diagnosis-input {input.diagnoses} --dai-input {input.dai_scores} --medication-input {input.medications} --age-time-input {input.age_time} --output {output} --visit {wildcards.visit} ' + ignore)



rule discovery_outcomes_dai_data_cluster_diagnosis:
    input:
        expand(rules.discovery_outcomes_dai_data_cluster_diagnosis_pattern.output, visit=VISITS)



rule discovery_outcomes_dai_data_cluster_pattern:
    output:
        'tables/discovery/outcomes/dai/data/clusters/visit_{visit}.feather'
    input:
        clusters=rules.clusters_discovery_full.output,
        localizations=rules.clusters_discovery_localizations.output,
        dai_scores=rules.data_discovery_dai_projections.output,
        medications=rules.data_discovery_medications.output,
        age_time=rules.data_discovery_basics.output,
        patient_filter=rules.data_discovery_filtered.output.filter,
        flags=rules.data_discovery_filtered.output.flag
    params:
        ignore=['nsaid_status', 'diagnosis_6_months']
    version:
        v('scripts/dai_associations/combine_data.py')
    run:
        ignore = ' '.join('--ignore {}'.format(x) for x in params.ignore)
        shell('python scripts/dai_associations/combine_data.py --filter-input {input.patient_filter} --cluster-input {input.clusters} --localization-input {input.localizations} --dai-input {input.dai_scores} --medication-input {input.medications} --age-time-input {input.age_time} --output {output} --visit {wildcards.visit} ' + ignore)



rule discovery_outcomes_dai_data_cluster:
    input:
        expand(rules.discovery_outcomes_dai_data_cluster_pattern.output, visit=VISITS)



rule discovery_outcomes_dai_data_diagnosis_pattern:
    output:
        'tables/discovery/outcomes/dai/data/diagnoses/visit_{visit}.feather'
    input:
        diagnoses=rules.diagnoses_discovery_diagnoses.output,
        dai_scores=rules.data_discovery_dai_projections.output,
        medications=rules.data_discovery_medications.output,
        age_time=rules.data_discovery_basics.output,
        patient_filter=rules.data_discovery_filtered.output.filter,
        flags=rules.data_discovery_filtered.output.flag
    params:
        ignore=['nsaid_status', 'diagnosis_6_months']
    version:
        v('scripts/dai_associations/combine_data.py')
    run:
        ignore = ' '.join('--ignore {}'.format(x) for x in params.ignore)
        shell('python scripts/dai_associations/combine_data.py --filter-input {input.patient_filter} --diagnosis-input {input.diagnoses} --dai-input {input.dai_scores} --medication-input {input.medications} --age-time-input {input.age_time} --output {output} --visit {wildcards.visit} ' + ignore)



rule discovery_outcomes_dai_data_diagnosis:
    input:
        expand(rules.discovery_outcomes_dai_data_diagnosis_pattern.output, visit=VISITS)



rule discovery_outcomes_dai_data_null_pattern:
    output:
        'tables/discovery/outcomes/dai/data/null/visit_{visit}.feather'
    input:
        dai_scores=rules.data_discovery_dai_projections.output,
        medications=rules.data_discovery_medications.output,
        age_time=rules.data_discovery_basics.output,
        patient_filter=rules.data_discovery_filtered.output.filter,
        flags=rules.data_discovery_filtered.output.flag
    params:
        ignore=['nsaid_status', 'diagnosis_6_months']
    version:
        v('scripts/dai_associations/combine_data.py')
    run:
        ignore = ' '.join('--ignore {}'.format(x) for x in params.ignore)
        shell('python scripts/dai_associations/combine_data.py --filter-input {input.patient_filter} --dai-input {input.dai_scores} --medication-input {input.medications} --age-time-input {input.age_time} --output {output} --visit {wildcards.visit} ' + ignore)



rule discovery_outcomes_dai_data_null:
    input:
        expand(rules.discovery_outcomes_dai_data_null_pattern.output, visit=VISITS)



# Targets.

rule discovery_outcomes_dai_data_tables:
    input:
        rules.discovery_outcomes_dai_data_cluster_diagnosis.input,
        rules.discovery_outcomes_dai_data_cluster.input,
        rules.discovery_outcomes_dai_data_diagnosis.input,
        rules.discovery_outcomes_dai_data_null.input



rule discovery_outcomes_dai_data:
    input:
        rules.discovery_outcomes_dai_data_tables.input
