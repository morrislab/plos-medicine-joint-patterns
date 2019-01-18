# Determines which patient groups predict disease activity indicator scores.

library(argparse)

library(data.table)

library(glmnet)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--dai-score-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--visits', type = 'integer', nargs = '+', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 89234922)

args <- parser$parse_args(strsplit('--dai-score-input tables/discovery/data/dai/scores.csv --cluster-input tables/discovery/clusters/clusters.csv --visits 2 3 --output tables/discovery/nmf/output/dai_associations/stats.csv', ' ')[[1]])



# Load the data.

message('Loading data')

dt.dai.scores <- fread(args$dai_score_input)

dt.clusters <- fread(args$cluster_input, colClasses = c(classification = 'character'))

setkey(dt.clusters, subject_id)



# Filter the data.

message('Filtering data')

dt.dai.scores <- dt.dai.scores[visit_id %in% c(min(args$visits) - 1, args$visits)]



# Cast the data.

message('Casting data')

dt.dai.scores.casted <- dcast(dt.dai.scores, subject_id ~ visit_id, value.var = 'PC2')

setnames(dt.dai.scores.casted, colnames(dt.dai.scores.casted)[-1], paste0('score_', colnames(dt.dai.scores.casted)[-1]))

setkey(dt.dai.scores.casted, subject_id)



# Filter the data down to common patients.

message('Filtering data')

dt.dai.scores.casted <- dt.dai.scores.casted[J(dt.clusters$subject_id)]



# Merge the data.

message('Merging data')



# Conduct LASSO regression.

message('Conducting LASSO regularization')

set.seed(args$seed)

targets <- dt.dai.scores.casted$score_2

predictors <- dt.clusters[dt.dai.scores.casted[, .(subject_id, score_2)]]

cv.res <- cv.glmnet(as.matrix(predictors[, -1, with = FALSE]), targets)
