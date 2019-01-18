# Generates survival curve data for diagnoses.

library(argparse)
library(data.table)
library(feather)
library(survival)
library(dplyr)
library(dtplyr)
library(stringr)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the Feather file to read hazard data from')
parser$add_argument('--output', required = TRUE, help = 'the Feather file to write curve data to')
args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- read_feather(args$input) %>%
    setDT



# Generate the data.

message('Generating curve data')

make.shifted.data <- function (X) {

	setorder(X, time)

	data.table(
	    time = tail(X$time, -1) - 1e-6,
	    X %>%
	        select(-time) %>%
	        head(-1)
	)

}

survfit.result <- survfit(Surv(duration, event_status) ~ rf, dt.data)

dt.base <- data.table(
	strata = rep(names(survfit.result$strata), survfit.result$strata),
	time = survfit.result$time,
	survival = survfit.result$surv,
	lower = survfit.result$lower,
	upper = survfit.result$upper
)

extracted.strata <- str_match(dt.base$strata, '^rf=(.+)$')

dt.base[, `:=`(
	rf = gsub('\\s', '', extracted.strata[, 2]),
	strata = NULL
)]

dt.shifted <- dt.base %>%
    group_by(rf) %>%
    do(make.shifted.data(.))

dt.shifted[, `:=`(
	rf = NULL
)]

dt.output <- list(dt.base, dt.shifted) %>%
    rbindlist(use.names = TRUE)



# Write the output.

message('Writing output')

dt.output %>%
    write_feather(args$output)
