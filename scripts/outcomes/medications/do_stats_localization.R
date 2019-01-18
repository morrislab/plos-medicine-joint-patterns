library(argparse)

library(data.table)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the CSV file to read medication information from')

parser$add_argument('--output', required = TRUE, help = 'the CSV file to write results to')

parser$add_argument('--iterations', type = 'integer', default = 2000, help = 'the number of chi-square test bootstraps to conduct')

parser$add_argument('--seed', type = 'integer', default = 847259, help = 'the seed to initialize the chi-square test bootstrap with')

args <- parser$parse_args()



# Load the data.

message('Loading medications')

dt.medications <- fread(args$input)



# Remove NSAIDs.

message('Removing NSAIDs')

dt.medications <- dt.medications[medication != 'nsaid']



# Remove diagnoses.

message('Removing diagnoses')

dt.medications <- dt.medications[cls_type == 'classification']

dt.medications[, cls_type := NULL]



# Calculate localizations.

message('Calculating localizations')

dt.medications[, localization := ifelse(grepl('limited$', cls), 'limited', 'undifferentiated')]

dt.medications[, `:=`(
	cls = NULL,
	proportion = NULL
)]

dt.medications <- dt.medications[, .(count = sum(count)), by = .(visit_id, medication, status, localization)]



# Calculate the global distribution of patients on medications.

message('Calculating global distributions')

dt.global.dists <- dt.medications[, .(count = sum(count)), by = .(visit_id, medication, status)]

dt.global.dists.casted <- dcast(dt.global.dists, visit_id + medication ~ status, fill = 0)

setkey(dt.global.dists.casted, visit_id, medication)



# Conduct statistics.

message('Conducting statistics')

dt.results <- rbindlist(llply(dt.medications[, unique(localization)], function (l) {

	dt.subset <- dt.medications[localization == l]

	dt.subset.casted <- dcast(dt.subset, visit_id + localization + medication ~ status, value.var = 'count', fill = 0)

	do.stats <- function (dt.slice, visit_id, medication) {

		message('Localization ', l, ', Visit ', visit_id, ', Medication ', medication)

		observed <- unlist(dt.slice)

		query.key <- list(visit_id, medication)

		reference <- unlist(dt.global.dists.casted[query.key][, .(`FALSE`, `TRUE`)])

		chisq.res <- chisq.test(observed, p = reference, rescale.p = TRUE, simulate.p.value = TRUE, B = args$iterations)

		data.table(x2 = chisq.res$statistic, p = chisq.res$p.value, pos_stdres = chisq.res$stdres['TRUE'])

	}

	dt.subset.casted[, do.stats(.SD, visit_id, medication), by = .(visit_id, localization, medication)]

}))

dt.results <- dt.results[!is.na(p)]

dt.results[, p_adjusted := p.adjust(p, method = 'b'), by = .(visit_id, medication)]

dt.results[, p_residual := pnorm(-abs(pos_stdres)) * 2]

dt.results[, p_residual_adjusted := p.adjust(p_residual), by = .(visit_id, medication)]



# Write the output.

message('Writing output')

write.csv(dt.results, args$output, row.names = FALSE)
