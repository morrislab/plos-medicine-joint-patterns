# Calculates associations between patient groups and outcome measures.

library(argparse)

library(data.table)

library(feather)

library(moments)

library(car)

library(dplyr)

library(dtplyr)

library(gtools)

rm(list = ls())



# Obtain arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--continuous-output', required = TRUE)

parser$add_argument('--categorical-output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 54673452)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))

dt.data[, classification := relevel(classification, names(which.max(table(classification))))]

setkey(dt.data, subject_id)



# Determine which fields are categorical.

message('Determining variable types')

n.unique <- sapply(dt.data %>% select(-subject_id), function (x) {
	length(unique(na.omit(x)))
})

categorical.variables <- names(n.unique[n.unique <= 2])

continuous.variables <- names(n.unique[n.unique > 2])



# Extract continuous and categorical sets.

message('Splitting data')

dt.melted.continuous <- melt(dt.data %>% select(subject_id, classification, one_of(continuous.variables)), id.vars = c('subject_id', 'classification'), na.rm = TRUE)

dt.melted.categorical <- melt(dt.data %>% select(subject_id, classification, one_of(categorical.variables)), id.vars = c('subject_id', 'classification'), na.rm = TRUE)



# Do stats on continuous variables.

message('Running linear regression')

do.lm <- function (.SD, cls) {

	# Transform the data.

	gamma <- -min(.SD$value) + 1

	shifted.values <- .SD$value + gamma

	bc.res <- boxCox(shifted.values ~ 1, plotit = FALSE)

	lambda <- with(bc.res, x[which.max(y)])

	transformed.values <- scale(bcPower(shifted.values, lambda))

	# Conduct linear regression.

	lm.result <- lm(as.formula(paste('transformed.values ~', cls)), .SD)

	summary.res <- summary(lm.result)

	lm.coefs <- coefficients(summary.res)

	r2 <- summary.res$r.squared

	fstats.model <- summary.res$fstatistic

	dt.result <- data.table(lm.result$xlevels[[cls]], lm.coefs, r2, fstats.model[1], pf(fstats.model[1], fstats.model[2], fstats.model[3], lower.tail = FALSE), kurtosis(.SD$value), skewness(.SD$value), lambda, gamma, kurtosis(transformed.values), skewness(transformed.values))

	setnames(dt.result, c('term', 'lm_estimate', 'lm_stderr', 't', 'p', 'r2', 'f', 'p_model', 'kurtosis_original', 'skewness_original', 'lambda', 'gamma', 'kurtosis_transformed', 'skewness_transformed'))

	dt.result

}

do.lms <- function (.SD) {

	rbindlist(list(do.lm(.SD, 'classification')))

}

dt.results.lm <- dt.melted.continuous[, do.lms(.SD), by = .(variable), .SDcols = c('classification', 'value')]



# Do stats on categorical variables.

message("Running chi-square tests")

do.chisq <- function (.SD) {

	tab <- with(.SD, table(classification, value))

	set.seed(args$seed)

	chisq.result <- chisq.test(tab, simulate.p.value = TRUE)

	result <- data.table(melt(chisq.result$stdres, variable.name = 'value', value.name = 'stdres'))

	p <- pnorm(-abs(result$stdres)) * 2

	result[, `:=`(
		stars = stars.pval(p),
		chisq = chisq.result$statistic,
		chisq_p = chisq.result$p.value
	)]

}

dt.results.chisq <- dt.melted.categorical[, do.chisq(.SD), by = .(variable)]



# Write the outputs.

message('Writing outputs')

write.csv(dt.results.lm, file = args$continuous_output, row.names = FALSE)

write.csv(dt.results.chisq, file = args$categorical_output, row.names = FALSE)
