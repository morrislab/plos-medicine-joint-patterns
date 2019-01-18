# Conducts chi-square tests to determine which localizations are enriched or
# depleted given administration of medications for each cluster.

library(argparse)

library(data.table)

library(stringr)

library(plyr)

library(dplyr)

library(dtplyr)

library(tidyr)

library(doMC)

library(xlsx)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file containing a medication summary for clusters with localizations')

parser$add_argument('--output', required = TRUE, help = 'the Excel file to export statistics to')

parser$add_argument('--iterations', type = 'integer', default = 2000)

parser$add_argument('--threads', type = 'integer', default = 1)

parser$add_argument('--seed', type = 'integer', default = 45726930)

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- fread(args$input)

df.data <- df.data[grepl('^[A-Z]_', cls) & (status == TRUE)]

df.data[, `:=`(
	classification = str_extract(cls, '^[A-Z]'),
	localization = sub('_', '', str_extract(cls, '_.+$'))
)]



message('Completing data')

df.data <- data.table(df.data %>% complete(visit_id, medication, classification, localization, fill = list(count = 0, proportion = 0)))



message('Conducting chi-square tests')

registerDoMC(args$threads)

results <- df.data %>% dlply(.(medication, visit_id, classification), function (X) {

	if (sum(X$count) >= 1) {

		med <- unique(X$medication)

		visit.id <- unique(X$visit_id)

		classification <- unique(X$classification)

		message('medication=', med, ', visit_id=', visit.id, ', classification=', classification)

		list(
			medication = med,
			visit.id = visit.id,
			classification = classification,
			localizations = X$localization,
			result = chisq.test(X$count, simulate.p.value = TRUE, B = args$iterations)
		)

	}

}, .parallel = TRUE)

df.p.values <- data.table(ldply(results, function (X) {

	if (!is.null(X)) {

		with(X, data.frame(medication = medication, visit_id = visit.id, classification = classification, statistic = result$statistic, p = result$p.value))

	}

}))

df.stdres <- data.table(ldply(results, function (X) {

	if (!is.null(X)) {

		with(X, data.frame(medication = medication, visit_id = visit.id, classification = classification, localization = localizations, stdres = result$stdres))

	}

}))

df.p.values[, p_adjust := p.adjust(p, method = 'bonferroni'), by = .(medication, visit_id)]



# Write output.

message('Writing output')

write.xlsx(df.p.values, args$output, 'P-values', row.names = FALSE)

write.xlsx(df.stdres, args$output, 'Std residuals', row.names = FALSE, append = TRUE)
