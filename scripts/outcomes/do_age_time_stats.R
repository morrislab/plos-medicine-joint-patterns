# Determines which classifications or ILAR subtypes predict age of and time to diagnosis.

library(argparse)

library(data.table)

library(feather)

library(moments)

library(car)

rm(list = ls())



# Obtain arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--classification-input', required = TRUE)

parser$add_argument('--diagnosis-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$data_input))

dt.data[, `:=`(
	time_to_diagnosis = symptom_onset_to_diagnosis_days / 30.4368499,
	age_of_diagnosis = diagnosis_age_days / 365.242199
)]

dt.data <- dt.data[, .(subject_id, time_to_diagnosis, age_of_diagnosis)]

setkey(dt.data, subject_id)



# Load the classifications.

message('Loading and mapping classifications')

dt.classifications <- fread(args$classification_input)

dt.classifications[, classification := factor(classification)]

dt.classifications[, classification := relevel(classification, names(which.max(table(classification))))]

setkey(dt.classifications, subject_id)



# Load the diagnoses.

dt.diagnoses <- fread(args$diagnosis_input)

dt.diagnoses <- dt.diagnoses[diagnosis != '']

dt.diagnoses[, subdiagnosis := NULL]

diagnosis.map <- c(
	"Oligoarthritis" = 'O',
	"RF-positive polyarthritis" = 'P+',
	"RF-negative polyarthritis" = 'P-',
	"Enthesitis-related arthritis" = 'ERA',
	"Psoriatic arthritis" = 'Ps',
	"Systemic arthritis" = 'S',
	"Undifferentiated arthritis" = 'U'
)

dt.diagnoses[, diagnosis := factor(diagnosis.map[diagnosis])]

dt.diagnoses[, diagnosis := relevel(diagnosis, names(which.max(table(diagnosis))))]

setkey(dt.diagnoses, subject_id)



# Merge the data.

message('Merging data')

dt.merged <- dt.data[dt.classifications, nomatch = 0][dt.diagnoses, nomatch = 0]



# Melt the data.

message('Melting data')

dt.melted <- melt(dt.merged, id.vars = c('subject_id', 'classification', 'diagnosis'), na.rm = TRUE)



# Conduct linear modelling.

message('Conducting linear regression')

do.lm <- function (.SD, cls) {

	# Transform the data.

	gamma <- -min(.SD$value) + 1

	shifted.values <- .SD$value + gamma

	bc.res <- boxCox(shifted.values ~ 1, plotit = FALSE)

	lambda <- with(bc.res, x[which.max(y)])

	transformed.values <- bcPower(shifted.values, lambda)

	# Conduct linear regression.

    lm.result <- lm(as.formula(paste('scale(transformed.values) ~', cls)), .SD)

    summary.res <- summary(lm.result)

    lm.coefs <- coefficients(summary.res)

    r2 <- summary.res$r.squared

    fstats.model <- summary.res$fstatistic

    dt.result <- data.table(lm.result$xlevels[[cls]], lm.coefs, r2, fstats.model[1], pf(fstats.model[1], fstats.model[2], fstats.model[3], lower.tail = FALSE), kurtosis(.SD$value), skewness(.SD$value), lambda, gamma, kurtosis(transformed.values), skewness(transformed.values))

    setnames(dt.result, c('term', 'lm_estimate', 'lm_stderr', 't', 'p', 'r2', 'f', 'p_model', 'kurtosis_original', 'skewness_original', 'lambda', 'gamma', 'kurtosis_transformed', 'skewness_transformed'))

    dt.result

}

do.lms <- function (.SD) {

    rbindlist(list(do.lm(.SD, 'classification'), do.lm(.SD, 'diagnosis')))

}

dt.results <- dt.melted[, do.lms(.SD), by = .(variable), .SDcols = c('classification', 'diagnosis', 'value')]



# Write the output.

message('Writing output')

write.csv(dt.results, args$output, row.names = FALSE)
