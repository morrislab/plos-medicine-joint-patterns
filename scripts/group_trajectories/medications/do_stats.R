# Conducts statistics to determine which patient groups are enriched or depleted
# for individual medications among patients with non-zero joint involvement
# compared to those with zero joint involvement.

library(argparse)

library(feather)

library(plyr)

library(dplyr)

library(tidyr)

library(xlsx)

rm(list = ls())

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--iterations', type = 'integer', default = 2000)

args <- parser$parse_args()



# Load the data.

message('Loading medications')

df.medications <- read_feather(args$input)



# Remove NSAIDs.

message('Removing NSAIDs')

df.medications <- df.medications %>%
	filter(medication != 'nsaid')



# Conduct statistics.

message('Conducting statistics')

results <- dlply(df.medications, .(visit_id, medication), function (X) {

	visit.id <- unique(X$visit_id)

	medication <- unique(X$medication)

	dists <- data.frame(
		X %>%
			group_by(baseline_classification, zero_joints, status) %>%
			summarize(count = n())
	)

	dists <- dists %>%
		complete(baseline_classification, zero_joints, status, fill = list(count = 0))

	dist.zero <- dists %>%
		filter(zero_joints == TRUE & status == TRUE)

	dist.nonzero <- dists %>%
		filter(zero_joints == FALSE & status == TRUE)

	if (sum(dist.zero$count) > 0 && sum(dist.nonzero$count) > 0) {

		fisher.res <- fisher.test(dist.nonzero$count, dist.zero$count)

		stdres <- (dist.nonzero$count - dist.zero$count) / sqrt(dist.zero$count)

		df.fisher <- data.frame(
			visit_id = visit.id,
			medication = medication,
			p = fisher.res$p.value
		)

		df.stdres <- data.frame(
			visit_id = visit.id,
			medication = medication,
			baseline_classification = dist.nonzero$baseline_classification,
			stdres = stdres
		)

		list(fisher = df.fisher, stdres = df.stdres)

	}

}, .progress = 'time')

df.fisher <- ldply(results, function (X) {

	X$fisher

})

df.stdres <- ldply(results, function (X) {

	X$stdres

})



message('Adjusting P-values')

df.fisher <- df.fisher %>%
	group_by(visit_id) %>%
	transform(p_adjusted = p.adjust(p, method = 'bonferroni'))



# Write the output.

message('Writing output')

write.xlsx(df.fisher, file = args$output, sheetName = 'Fisher', row.names = FALSE)

write.xlsx(df.stdres, file = args$output, sheetName = 'Stdres', row.names = FALSE, append = TRUE)
