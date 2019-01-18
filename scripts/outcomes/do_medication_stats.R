# Conducts statistics on medication statuses.

library(argparse)

library(data.table)

library(gtools)

library(plyr)

library(doMC)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--iterations', type = 'integer', default = 2000)

parser$add_argument('--seed', type = 'integer', default = 73528552)

parser$add_argument('--threads', type = 'integer', default = 1, help = 'the number of threads to use')

args <- parser$parse_args()



# Load the data.

message('Loading medications')

dt.medications <- fread(args$input)



# Remove NSAIDs.

message('Removing NSAIDs')

dt.medications <- dt.medications[medication != 'nsaid']



# Conduct statistics.

message('Conducting statistics')

dt.global.dists <- dt.medications[grepl('^classification', cls_type), .(count = sum(count)), by = .(visit_id, medication, status)]

dt.global.dists.casted <- dcast(dt.global.dists, visit_id + medication ~ status, fill = 0)

setkey(dt.global.dists.casted, visit_id, medication)

registerDoMC(args$threads)

set.seed(args$seed)

dt.results <- rbindlist(llply(dt.medications[, unique(cls_type)], function (cls.type) {

	dt.subset <- dt.medications[cls_type == cls.type]

	dt.subset.casted <- dcast(dt.subset, visit_id + cls + medication ~ status, value.var = 'count', fill = 0)

	do.stats <- function (dt.slice, visit_id, cls, medication) {

		message('Classification type ', cls.type, ', Visit ', visit_id, ', Classification ', cls, ', Medication ', medication)

		observed <- unlist(dt.slice)

		query.key <- list(visit_id, medication)

		reference <- unlist(dt.global.dists.casted[query.key][, .(`FALSE`, `TRUE`)])

		chisq.res <- chisq.test(observed, p = reference, rescale.p = TRUE, simulate.p.value = TRUE, B = args$iterations)

		data.table(x2 = chisq.res$statistic, p = chisq.res$p.value, pos_stdres = chisq.res$stdres['TRUE'])

	}

	dt.subset.casted[, do.stats(.SD, visit_id, cls, medication), by = .(visit_id, cls, medication)]

}, .parallel = TRUE))

dt.results <- dt.results[!is.na(p)]

dt.results[, p_adjusted := p.adjust(p), by = .(visit_id, medication)]

dt.results[, p_residual := pnorm(-abs(pos_stdres)) * 2]

dt.results[, p_residual_adjusted := p.adjust(p_residual), by = .(visit_id, medication)]



# Write the output.

message('Writing output')

write.csv(dt.results, args$output, row.names = FALSE)
