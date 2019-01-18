# Determines if patient groups differ by site counts.

library(argparse)

library(data.table)

library(quantreg)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--tau', type = 'double', nargs = '+', default = 0.5)

parser$add_argument('--seed', type = 'integer', default = 8932742)

args <- parser$parse_args()



# Load data.

message('Loading data')

dt.data <- fread(args$data_input)

message('Loading clusters')

dt.clusters <- fread(args$cluster_input)

dt.clusters[, classification := factor(classification)]

dt.clusters[, classification := relevel(classification, names(which.min(table(classification))))]

setkey(dt.clusters, subject_id)



# Calculate site counts.

message('Calculating site counts')

dt.counts <- dt.data[, .(count = rowSums(.SD)), keyby = .(subject_id)]

setkey(dt.counts, subject_id)



# Merge the data.

message('Merging data')

dt.merged <- dt.counts[dt.clusters]



# Conduct quantile regression.

message('Conducting quantile regression')

do.qr <- function (tau) {

    rq.null <- rq(count ~ 1, data = dt.merged, tau = tau)

    rq.res <- rq(count ~ classification, data = dt.merged, tau = tau)

    anova.res <- anova(rq.null, rq.res)

    set.seed(args$seed)

    summary.res <- summary(rq.res, se = 'boot')

    coef.res <- coef(summary.res)

    dt.result <- data.table(rq.res$xlevels[['classification']], coef.res)

    setnames(dt.result, c('term', 'coefficient', 'std_error', 't', 'p'))

    dt.result[, `:=`(
        tau = tau,
        anova_f = anova.res$table$Tn,
        anova_p = anova.res$table$pvalue
    )]

}

dt.results <- rbindlist(llply(args$tau, do.qr))



# Write the output.

message('Writing output')

write.csv(dt.results, args$output, row.names = FALSE)
