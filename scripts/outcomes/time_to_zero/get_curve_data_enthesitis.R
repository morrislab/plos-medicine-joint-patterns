# Generates survival curve data for localizations.

library(argparse)
library(data.table)
library(feather)
library(survival)
library(dplyr)
library(dtplyr)
library(stringr)
rm(list = ls())

parser <- ArgumentParser()
parser$add_argument('--data-input', required = TRUE, help = 'the Feather file to read hazard data from')
parser$add_argument('--other-input', required = TRUE, help = 'the Feather file to read other data from')
parser$add_argument('--output', required = TRUE, help = 'the Feather file to write curve data to')
args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- read_feather(args$data_input) %>% setDT

message('Loading other data')

dt.other <- read_feather(args$other_input) %>% setDT

dt.data <- dt.data %>%
	left_join(dt.other %>% select(subject_id, enthesitis))



# Generate the data.

message('Generating curve data')

make.shifted.data <- function (X) {

	setorder(X, time)

	data.table(time = tail(X$time, -1) - 1e-6, X %>% select(-time) %>% head(-1))

}

survfit.result <- survfit(Surv(duration, event_status) ~ classification + enthesitis, dt.data)

dt.base <- data.table(
	strata = rep(names(survfit.result$strata), survfit.result$strata),
	time = survfit.result$time,
	survival = survfit.result$surv,
	lower = survfit.result$lower,
	upper = survfit.result$upper
)

extracted.strata <- str_match(dt.base$strata, '^classification=(.+), enthesitis=(.+)$')

dt.base[, `:=`(
	classification = gsub('\\s', '', extracted.strata[, 2]),
	enthesitis = extracted.strata[, 3],
	strata = NULL
)]

dt.shifted <- dt.base %>%
	group_by(classification, enthesitis) %>%
	do(make.shifted.data(.))

dt.shifted[, `:=`(
	classification = NULL,
	enthesitis = NULL
)]

dt.output <- rbindlist(list(dt.base, dt.shifted), use.names = TRUE)



# Write the output.

message('Writing output')

write_feather(dt.output, args$output)
