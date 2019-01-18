import datetime
import itertools as it

from box import Box
from os import mkdir, uname
from os.path import exists, join, getmtime

def v(x):
    """
    Calculates the version of a given file.
    """

    return str(getmtime(x))

DEBUG = ' && exit 1'
LOG = ' 2>&1 | tee {log}'
LN_COMMAND = 'ln -sr'
if uname()[0] == 'Darwin':
    LN_COMMAND = f'g{LN_COMMAND}'
LN = '{LN_COMMAND} {input:q} {output}'
LN_ALT = '{LN_COMMAND} {input.input:q} {output}'

configfile: 'config/config.yaml'
config = Box(config)

VIRIDIS_PALETTE = config.viridis_palette
COHORTS = config.cohorts



rule all:
    input:



include: 'snakefiles/data.snakefile'
include: 'snakefiles/diagnoses.snakefile'
include: 'snakefiles/demographics.snakefile'
include: 'snakefiles/site_probabilities.snakefile'
include: 'snakefiles/co_occurrences.snakefile'
include: 'snakefiles/nmf.snakefile'
include: 'snakefiles/combined_bases.snakefile'
include: 'snakefiles/representative_sites.snakefile'
include: 'snakefiles/clusters.snakefile'
include: 'snakefiles/site_counts.snakefile'
include: 'snakefiles/homunculi.snakefile'
include: 'snakefiles/site_heatmap.snakefile'
include: 'snakefiles/circos.snakefile'
include: 'snakefiles/diagnosis_associations.snakefile'
include: 'snakefiles/localizations.snakefile'
include: 'snakefiles/validation_projections.snakefile'
include: 'snakefiles/outcomes.snakefile'
include: 'snakefiles/cluster_trajectories.snakefile'
include: 'snakefiles/crosstalk.snakefile'
include: 'snakefiles/variance_explained.snakefile'
include: 'snakefiles/reconstructions.snakefile'
include: 'snakefiles/q2.snakefile'



rule tables:
    input:
        rules.data_tables.input,
        rules.diagnoses_tables.input,
        rules.demographics_tables.input,
        rules.site_probabilities_tables.input,
        rules.co_occurrences_tables.input,
        rules.nmf_tables.input,
        rules.combined_bases_tables.input,
        rules.representative_sites_tables.input,
        rules.clusters_tables.input,
        rules.site_counts_tables.input,
        rules.homunculi_tables.input,
        rules.site_heatmap_tables.input,
        rules.circos_tables.input,
        rules.diagnosis_associations_tables.input,
        rules.localizations_tables.input,
        rules.validation_projections_tables.input,
        rules.outcomes_tables.input,
        rules.cluster_trajectories_tables.input,
        rules.crosstalk_tables.input,
        rules.variance_explained_tables.input,
        rules.reconstructions_tables.input,
        rules.q2_tables.input,



rule parameters:
    input:
        rules.data_parameters.input,
        rules.diagnoses_parameters.input,
        rules.demographics_parameters.input,
        rules.site_probabilities_parameters.input,
        rules.co_occurrences_parameters.input,
        rules.nmf_parameters.input,
        rules.combined_bases_parameters.input,
        rules.representative_sites_parameters.input,
        rules.clusters_parameters.input,
        rules.site_counts_parameters.input,
        rules.homunculi_parameters.input,
        rules.site_heatmap_parameters.input,
        rules.circos_parameters.input,
        rules.diagnosis_associations_parameters.input,
        rules.localizations_parameters.input,
        rules.validation_projections_parameters.input,
        rules.outcomes_parameters.input,
        rules.cluster_trajectories_parameters.input,
        rules.crosstalk_parameters.input,
        rules.variance_explained_parameters.input,
        rules.reconstructions_parameters.input,
        rules.q2_parameters.input,



rule figures:
    input:
        rules.data_figures.input,
        rules.diagnoses_figures.input,
        rules.demographics_figures.input,
        rules.site_probabilities_figures.input,
        rules.co_occurrences_figures.input,
        rules.nmf_figures.input,
        rules.combined_bases_figures.input,
        rules.representative_sites_figures.input,
        rules.clusters_figures.input,
        rules.site_counts_figures.input,
        rules.homunculi_figures.input,
        rules.site_heatmap_figures.input,
        rules.circos_figures.input,
        rules.diagnosis_associations_figures.input,
        rules.localizations_figures.input,
        rules.validation_projections_figures.input,
        rules.outcomes_figures.input,
        rules.cluster_trajectories_figures.input,
        rules.crosstalk_figures.input,
        rules.variance_explained_figures.input,
        rules.reconstructions_figures.input,
        rules.q2_figures.input,



rule everything:
    input:
        rules.tables.input,
        rules.parameters.input,
        rules.figures.input,



# Define cluster synchronization tasks.

RSYNC = 'rsync'
RSYNC_FLAGS = '--links -avzP'
RSYNC_TO = f'{RSYNC} {RSYNC_FLAGS} --delete'
RSYNC_FROM = f'{RSYNC} {RSYNC_FLAGS}'
REMOTE_PATH = (f'{config.sync.username}'
               f'@{config.sync.server}'
               f':{config.sync.remote_path}')

rule sync_to_cluster:
    run:
        for n in ['config', 'inputs', 'outputs', 'parameters', 'scripts', 'snakefiles', 'Snakefile', 'tables']:
            if n != 'Snakefile' and not exists(n):
                mkdir(n)
            shell('{RSYNC_TO} {n} {REMOTE_PATH}')



rule sync_from_cluster:
    run:
        for n in ['inputs', 'outputs', 'parameters', 'tables']:
            shell('{RSYNC_FROM} {REMOTE_PATH}/{n} .')
