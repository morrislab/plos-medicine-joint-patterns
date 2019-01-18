# Conducts binomial tests to determine which localizations are enriched or depleted.

library(argparse)

library(data.table)

library(stringr)

library(plyr)

library(dplyr)

library(dtplyr)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--base-summary-input', required = TRUE, help = 'the CSV containing a medication summary for clusters without localizations')

parser$add_argument('--summary-input', required = TRUE, help = 'the CSV file containing a medication summary for clusters with localizations')

parser$add_argument('--output', required = TRUE, help = 'the CSV file to export statistics to')

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.base <- fread(args$base_summary_input)

df.base <- df.base[grepl('^[A-Z]$', cls) & (status == TRUE)]

df.localizations <- fread(args$summary_input)

df.localizations <- df.localizations[grepl('^[A-Z]_', cls)]



message('Conducting binomial tests')

df.localizations[, `:=`(
	base_cluster = str_extract(cls, '^[A-Z]'),
	localization = sub('_', '', str_extract(cls, '_.+$'))
)]

df.stats <- data.table(ddply(df.localizations, .(medication, visit_id, base_cluster, localization), function (X) {

	med <- unique(X$medication)

	visit.id <- unique(X$visit_id)

	base.cluster <- unique(X$base_cluster)

	base.stats <- df.base[medication == med & visit_id == visit.id & cls == base.cluster]

	base.p <- if (nrow(base.stats) > 0) base.stats[status == TRUE, proportion] else 0

	successes <- (X %>% filter(status == TRUE))$count

	if (length(successes) < 1) {

		successes <- 0

	}

	failures <- (X %>% filter(status == FALSE))$count

	if (length(failures) < 1) {

		failures <- 0

	}

	binom.res <- binom.test(c(successes, failures), p = base.p, alternative = 'two.sided')

	with(binom.res, data.frame(statistic = statistic, p = p.value, observed_prob = estimate, null_prob = null.value))

}, .progress = 'time'))

df.stats[, p_adjust := p.adjust(p, method = 'bonferroni'), by = .(medication, visit_id, base_cluster)]



# Write output.

message('Writing output')

write.csv(df.stats, args$output, row.names = FALSE)
