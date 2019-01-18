# Calculates statistics to determine which groups are enriched for particular
# localizations.

library(argparse)

library(data.table)

library(plyr)

library(dplyr)

library(dtplyr)

library(tidyr)

library(doMC)

library(xlsx)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to load localizations from')

parser$add_argument('--output', required = TRUE, help = 'the Excel file to output results to')

parser$add_argument('--iterations', type = 'integer', default = 2000, help = 'the number of bootstrapped chi-square iterations to run')

parser$add_argument('--threads', type = 'integer', default = 1, help = 'the number of threads to use')

parser$add_argument('--seed', type = 'integer', default = 34629900)

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- fread(args$input)



# Conduct the stats.

message('Conducting statistics')

base.counts <- table(df.data$localization) %>%
	data.frame()

setnames(base.counts, c('localization', 'count'))

set.seed(args$seed)

registerDoMC(args$threads)

chisq.results <- df.data %>%
	dlply(.(classification), function (X) {

		classification <- unique(X$classification)

		counts <- X %>%
			group_by(localization) %>%
			summarize(count = n())

		counts <- counts %>%
			right_join(base.counts %>% select(localization), by = 'localization') %>%
			replace_na(list(count = 0))

		chisq.res <- chisq.test(counts$count, p = base.counts$count, rescale.p = TRUE, simulate.p.value = TRUE, B = args$iterations)

		list(
			classification = classification,
			localizations = counts$localization,
			chisq = chisq.res
		)

	}, .parallel = TRUE)

df.chisq <- ldply(chisq.results, function (X) {

	with(X, data.frame(classification = classification, statistic = chisq$statistic, p = chisq$p.value))

})

df.chisq <- df.chisq %>%
	transform(p_adjusted = p.adjust(p, method = 'bonferroni'))

df.stdres <- ldply(chisq.results, function (X) {

	with(X, data.frame(classification = classification, localization = X$localizations, stdres = chisq$stdres))

})



# Write the output.

message('Writing output')

write.xlsx(df.chisq, file = args$output, sheetName = 'Chisq', row.names = FALSE)

write.xlsx(df.stdres, file = args$output, sheetName = 'Stdres', row.names = FALSE, append = TRUE)
