# Conducts Z-tests to determine which patient groups are enriched or depleted on
# factors.

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



# Conduct Z-tests.

message('Conducting Z-tests')

do.z <- function (x) {

	# Note: since we already Z-transformed our data, we assume a mean of 0 and
	# standard deviation of 1. We are considering a one-sided test where the
	# alternative is a higher Z-score.

	zeta <- mean(x) / sqrt(1 / length(x))

	p <- pnorm(-zeta)

	data.frame(zeta = zeta, p = p)

}

df.results <- X %>%
	group_by(factor, classification) %>%
	do(do.z(.$z_score)) %>%
	ungroup() %>%
	mutate(
		p_adjusted = p.adjust(p, method = 'bonferroni'),
		fdr = p.adjust(p, method = 'fdr')
	)



# Write output.

message('Writing output')

df.results %>%
	as.data.frame %>%
	write.xlsx(args$output, sheetName = 'z_results', row.names = FALSE)

