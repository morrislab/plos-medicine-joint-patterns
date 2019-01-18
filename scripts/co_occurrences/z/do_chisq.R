# Conducts chi-squared tests to determine which site type pairs are significant.

library(argparse)
library(feather)
library(dplyr)
library(broom)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to read statistics from')
parser$add_argument('--output', required = TRUE, help = 'the CSV file to write results to')
args <- parser$parse_args()



# Load data.

message('Loading data')

X <- read_feather(args$input)



# Conduct chi-squared tests.

message('Conducting chi-squared tests')

run.chisq <- function (n.same, n.opposite) {

	if (n.same > 0 && n.opposite > 0) {

		set.seed(42)

		chisq.test(c(n.same, n.opposite)) %>%
			tidy()

	} else {

		data.frame(NULL)

	}

}

chisq.results <- X %>%
	group_by(reference_type, conditional_type) %>%
	do(run.chisq(.$n_same, .$n_opposite))

chisq.results <- chisq.results %>%
	ungroup() %>%
	mutate(
		p_bonferroni = p.adjust(p.value, method = 'bonferroni'),
		p_holm = p.adjust(p.value, method = 'holm'),
		p_fdr = p.adjust(p.value, method = 'fdr')
	) %>%
	select(-method)



# Write output.

message('Writing output')

chisq.results %>%
	write.csv(args$output, row.names = FALSE)

