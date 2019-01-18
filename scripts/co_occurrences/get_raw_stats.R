# Runs Fisher's exact test to determine which pairs of joints appear together at
# a higher rate than expected.

library(argparse)

library(data.table)

library(doParallel)

library(doMC)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--cluster-input')

parser$add_argument('--threads', type = 'integer', default = 1)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.data <- fread(args$data_input)

setnames(dt.data, 1, 'patient_id')

setkey(dt.data, patient_id)

dt.clusters <- if (!is.null(args$cluster_input)) {
	ret <- fread(args$cluster_input)
	setnames(ret, 1, 'patient_id')
} else {
	data.table(patient_id = dt.data$patient_id, classification = 0)
}

setkey(dt.clusters, patient_id)



message("Running Fisher's exact tests")

registerDoMC(args$threads)

unique.cls <- sort(unique(dt.clusters$classification))

site.combinations <- expand.grid(tail(colnames(dt.data), -1), tail(colnames(dt.data), -1))

dt.results <- (foreach(k = unique.cls) %:% foreach(i = seq(nrow(site.combinations)))) %do% {

	sites <- sapply(site.combinations[i, ], as.character)

	dt.filtered <- dt.data[J(dt.clusters[classification == k, 'patient_id']), sites, with = FALSE]

	tab <- table(dt.filtered)

	fisher.res <- fisher.test(tab, alternative = 'greater')

	data.table(classification = k, site_a = sites[1], site_b = sites[2], odds_ratio = fisher.res$estimate, p = fisher.res$p.value)

}

dt.results <- rbindlist(dt.results[[1]])



message('Writing output')

write.csv(dt.results, file = args$output, row.names = FALSE)
