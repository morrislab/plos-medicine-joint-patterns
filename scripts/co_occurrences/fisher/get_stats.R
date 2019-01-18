# Conducts Fisher's exact tests to determine which conditional co-occurrences
# have significantly different proportions between left and right conditional
# sites.

library(argparse)

library(data.table)

library(plyr)

library(dplyr)

library(dtplyr)

library(stringr)

library(qvalue)

rm(list = ls())

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to load input data from')

parser$add_argument('--output', required = TRUE, help = 'the CSV file to write statistics to')

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- fread(args$input)



# Drop sites without matching pairs.

message('Dropping sites without matching pairs')

df.data <- df.data %>%
	select(subject_id, ends_with('_left'), ends_with('_right'))



# Determine joint types.

message('Determining unique joint types')

joint.types <- unique(sub('_(left|right)$', '', colnames(df.data)[-1]))



# Run the tests.

message('Running tests')

df.results <- ldply(colnames(df.data)[-1], function (j) {

	joint.type <- str_replace(j, '_(left|right)$', '')

	same.side <- str_extract(j, '(left|right)$')

	opposite.side <- ifelse(same.side == 'left', 'right', 'left')

	involvements <- df.data %>%
		filter_(paste(j, '> 0'))

	n.total <- nrow(involvements)

	ldply(setdiff(joint.types, joint.type), function (k) {

		n.same <- involvements[[paste0(k, '_', same.side)]] %>% sum()

		n.opposite <- involvements[[paste0(k, '_', opposite.side)]] %>% sum()

		mat <- matrix(c(
			n.same,
			n.opposite,
			n.total - n.same,
			n.total - n.opposite
		), ncol = 2)

		fisher.res <- fisher.test(mat)

		with(fisher.res, data.frame(reference = j, conditional = k, odds_ratio = estimate, p = p.value))

	})

}) %>%
	data.table()

set.seed(42)

adjust.stats <- function (conditional, p) {

	qvalue.res <- qvalue(pmax(0, pmin(1, p)), pi0.method = 'bootstrap')

	data.table(
		conditional = conditional,
		p_bonferroni = p.adjust(p, method = 'bonferroni'),
		p_holm = p.adjust(p, method = 'holm'),
		p_fdr = p.adjust(p, method = 'fdr'),
		q = qvalue.res$qvalues,
		q_pi0 = qvalue.res$pi0,
		q_n_fp = with(qvalue.res, sapply(qvalues, function (x) x * sum(qvalues <= x)))
	)

}

df.adjusted <- df.results[, adjust.stats(conditional, p), by = .(reference)]

df.results <- setkey(df.results, reference, conditional)[setkey(df.adjusted, reference, conditional)]



# Write the output.

message('Writing output')

write.csv(df.results, args$output, row.names = FALSE)
