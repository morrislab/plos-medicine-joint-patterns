# Determines whether patient group predicts patient factor scores.

library(argparse)
library(feather)
library(plyr)
library(dplyr)
library(broom)
library(xlsx)
rm(list = ls())

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to load clusters and scores from')
parser$add_argument('--output', required = TRUE, help = 'the Excel file to output results to')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- read_feather(args$input)



# Relevel the classifications.

message('Relevelling classifications')

tab <- X$classification %>%
	table

top.classification <- which.max(tab) %>%
	names

X <- X %>%
	mutate(classification = relevel(classification, top.classification))



# Conduct linear regression to predict factor scores.

message('Conducting linear regression')

do.lm <- function (X) {

	lm(z_score ~ classification, X) %>%
		tidy %>%
		mutate(
			term = levels(X$classification)
		)

}

df.results <- X %>%
	group_by(factor) %>%
	do(do.lm(.)) %>%
	rename(
		cluster = term,
		std_error = std.error,
		t = statistic,
		p = p.value
	) %>%
	group_by(cluster) %>%
	mutate(
		p_adjusted = p.adjust(p, method = 'bonferroni')
	)



# Write output.

message('Writing output')

df.results %>%
	as.data.frame %>%
	write.xlsx(args$output, sheetName = 'lm_results', row.names = FALSE)

