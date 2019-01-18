# Generates survival curve data for diagnoses.

library(argparse)

library(data.table)

library(feather)

library(survival)

library(dplyr)

library(dtplyr)

library(stringr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the Feather file to read hazard data from')

parser$add_argument('--output', required = TRUE, help = 'the Feather file to write curve data to')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Generate the data.

message('Generating curve data')

make.shifted.data <- function (X) {

	setorder(X, time)

	data.table(time = tail(X$time, -1) - 1e-6, X %>% select(-time) %>% head(-1))

}

survfit.result <- survfit(Surv(duration, event_status) ~ classification, dt.data)

dt.base <- data.table(
	strata = rep(names(survfit.result$strata), survfit.result$strata),
	time = survfit.result$time,
	survival = survfit.result$surv,
	lower = survfit.result$lower,
	upper = survfit.result$upper
)

extracted.strata <- str_match(dt.base$strata, '^classification=(.+)$')

dt.base[, `:=`(
	classification = gsub('\\s', '', extracted.strata[, 2]),
	strata = NULL
)]

dt.shifted <- dt.base %>% group_by(classification) %>% do(make.shifted.data(.))

dt.shifted[, `:=`(
	classification = NULL
)]

dt.output <- rbindlist(list(dt.base, dt.shifted), use.names = TRUE)



# Write the output.

message('Writing output')

write_feather(dt.output, args$output)
