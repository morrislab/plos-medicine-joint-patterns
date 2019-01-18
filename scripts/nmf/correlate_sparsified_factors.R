# Correlates unsparsified scores and sparsified scores.

library(argparse)

library(data.table)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--unsparsified-input', required = TRUE)

parser$add_argument('--sparsified-input', required = TRUE)

parser$add_argument('--output')

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.unsparsified <- fread(args$unsparsified_input, header = TRUE)

setnames(dt.unsparsified, c('patient_id', seq(ncol(dt.unsparsified) - 1)))

dt.sparsified <- fread(args$sparsified_input, header = TRUE)

setnames(dt.sparsified, c('patient_id', seq(ncol(dt.sparsified) - 1)))



message('Melting data')

dt.unsparsified.melted <- melt(dt.unsparsified, id.var = 'patient_id', variable.name = 'factor', value.name = 'score_unsparsified', variable.factor = FALSE)

dt.unsparsified.melted[, factor := as.integer(factor)]

setkey(dt.unsparsified.melted, patient_id, factor)

dt.sparsified.melted <- melt(dt.sparsified, id.var = 'patient_id', variable.name = 'factor', value.name = 'score_sparsified', variable.factor = FALSE)

dt.sparsified.melted[, factor := as.integer(factor)]

setkey(dt.unsparsified.melted, patient_id, factor)



message('Merging data')

dt.merged <- dt.unsparsified.melted[dt.sparsified.melted]



message('Calculating correlations')

do.correlations <- function (unsparsified_scores, sparsified_scores) {

	pearson.cor.res <- cor.test(unsparsified_scores, sparsified_scores, method = 'pearson')

	spearman.cor.res <- cor.test(unsparsified_scores, sparsified_scores, method = 'spearman')

	data.table(pearson_r = pearson.cor.res$estimate, pearson_statistic = pearson.cor.res$statistic, pearson_p = pearson.cor.res$p.value, spearman_rho = spearman.cor.res$estimate, spearman_s = spearman.cor.res$statistic, spearman_p = spearman.cor.res$p.value)

}

dt.merged.cors <- dt.merged[, do.correlations(score_unsparsified, score_sparsified), keyby = .(factor)]



message('Writing output')

write.csv(dt.merged.cors, file = args$output, row.names = FALSE)

