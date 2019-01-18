# Runs binomial tests for co-involvement.

library(argparse)

library(feather)

library(data.table)

library(plyr)

library(doMC)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--co-occurrence-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--threads', type = 'integer', default = 1)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

df.data <- fread(args$data_input)

setnames(df.data, 1, 'patient_id')



message('Loading co-occurrences')

df.cooccurrences <- setDT(read_feather(args$co_occurrence_input))



df.base.probs <- df.cooccurrences[, .(reference_joint, co_occurring_joint, probability)]

setkey(df.base.probs, reference_joint, co_occurring_joint)



message('Calculating P-values')

sites <- tail(colnames(df.data), -1)

site.pairs <- expand.grid(reference = sites, co_occurring = sites, stringsAsFactors = FALSE)

registerDoMC(args$threads)

df.p.values <- rbindlist(alply(site.pairs, 1, function (X) {

	# Get the cohort-wide probability involvement probability.

	base.prob <- df.base.probs[J(X), probability]

	# Get the conditional involvements.

	df.cond.involvements <- df.data[, unlist(X), with = FALSE]

	setnames(df.cond.involvements, c('reference', 'co_occurring'))

	df.cond.involvements <- df.cond.involvements[reference > 0]

	# Run the binomial test.

	n.cond <- sum(df.cond.involvements$co_occurring)

	binom.test.result <- binom.test(c(n.cond, nrow(df.cond.involvements) - n.cond), p = base.prob, alternative = 'greater')

	data.table(X, statistic = binom.test.result$statistic, p = binom.test.result$p.value)

}, .parallel = TRUE))

df.p.values[, p_adjusted := p.adjust(p)]



message('Writing output')

write.csv(df.p.values, args$output, row.names = FALSE)
