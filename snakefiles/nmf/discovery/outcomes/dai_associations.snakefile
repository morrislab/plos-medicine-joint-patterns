# Associates patient groups with disease activity using LASSO regression.

DISCOVERY_NMF_OUTCOMES_DAI_ASSOCIATIONS_N = 2


rule nmf_discovery_outcomes_dai_association_stats:
    input:
        dai_scores=rules.data_discovery_dai_projections.output,
        clusters=rules.clusters_discovery_nx.output
    output:
        'tables/discovery/nmf/output/dai_associations/stats.csv'
    version:
        v('scripts/dai_associations/predict_dai_lasso.R')
    shell:
        'scripts/dai_associations/predict_dai_lasso.R --dai-score-input {input.dai_scores} --cluster-input {input.clusters} --output {output}'



# rule nmf_discovery_outcomes_dai_association_figure:
#     input:
#         dai_scores=rules.nmf_discovery_outcomes_dai_association_data.output
#     output:
#         'figures/discovery/nmf/outcomes/dai_associations/associations.pdf'
#     version:
#         v('scripts/dai_associations/plot_associations.R')
#     shell:
#         'Rscript scripts/dai_associations/plot_associations.R --data-input {input.dai_scores} --'



rule nmf_discovery_outcomes_dai_associations:
    input:
        rules.nmf_discovery_outcomes_dai_association_stats.output
