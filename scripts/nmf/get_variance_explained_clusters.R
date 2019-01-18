# Calculates variance explained from a classification on an original
# data set.

library(argparse)

library(data.table)

library(doMC)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--predictor-input', required = TRUE)

parser$add_argument('--response-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--processes', type = 'integer')

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.predictors <- fread(args$predictor_input, header = TRUE)

setnames(dt.predictors, 1, 'id')

setkey(dt.predictors, id)

dt.responses <- fread(args$response_input)

setnames(dt.responses, 1, 'id')

setkey(dt.responses, id)



message('Aligning data')

dt.ids <- dt.predictors[, .(id)][dt.responses[, .(id)], nomatch = 0]

dt.predictors <- dt.predictors[dt.ids, nomatch = 0]

dt.responses <- dt.responses[dt.ids, nomatch = 0]



message('Dropping variables with only one unique value')

n.unique <- sapply(dt.responses, function (x) length(unique(x)))

dt.responses <- dt.responses[, n.unique > 1, with = FALSE]



message('Calculating global variance explained')

registerDoMC(args$processes)

global.r2s <- foreach(j = 2:ncol(dt.responses), .combine = 'c') %dopar% {

    summary.res <- summary(lm(data.matrix(dt.responses[, j, with = FALSE]) ~ dt.predictors$classification))

    summary.res$r.squared

}

dt.global <- data.table(classification = -1, percent_variance_explained = mean(global.r2s) * 100)



message('Calculating per-classification variance explained')

all.clusters <- dt.predictors[, sort(unique(classification))]

dt.var <- rbindlist(foreach(k = all.clusters) %dopar% {

    message(paste('Starting k =', k))

    all.r2s <- foreach(j = 2:ncol(dt.responses), .combine = 'c') %do% {

        predictor.vec <- factor(dt.predictors$classification == k)

        summary.res <- summary(lm(data.matrix(dt.responses[, j, with = FALSE]) ~ predictor.vec))

        summary.res$r.squared

    }

    dt.result <- data.table(classification = k, percent_variance_explained = mean(all.r2s) * 100)

    message(paste('Done k =', k))

    dt.result

})



message('Writing output')

write.csv(rbindlist(list(dt.global, dt.var)), file = args$output, row.names = FALSE)



message('Done')
