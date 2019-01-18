# Determines whether certain patient group trajectories are enriched or
# depleted.

library(argparse)

library(data.table)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--cohort-classification-input')

parser$add_argument('--p-value-output', required = TRUE)

parser$add_argument('--std-residual-output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 81308142)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.clusters <- fread(args$input, header = TRUE)

setnames(dt.clusters, 1, 'patient_id')

dt.base.probabilities <- {if (!is.null(args$cohort_classification_input)) {

	dt.result <- fread(args$cohort_classification_input)

	dt.result <- dt.result[, .(count = .N), keyby = .(visit_id, classification)]

	dt.result[, probability := count / sum(count), by = .(visit_id)]

} else NULL}



# For pairs of visits, conduct chi-square tests. Consider only consecutive
# visits.

message('Conducting chi-square tests')

visit.combinations <- data.table(a = dt.clusters[, head(sort(unique(visit_id)), -1)])

visit.combinations[, b := a + 1]

multiplier <- nrow(visit.combinations)

set.seed(args$seed)

chisq.results <- dlply(visit.combinations, .(a, b), function (df.slice) {

    dt.a <- dt.clusters[visit_id == df.slice$a]

    dt.a <- dt.a[classification != '']

    dt.a[, visit_id := NULL]

    setnames(dt.a, 2, 'cluster_a')

    setkey(dt.a, 'patient_id')

    dt.b <- dt.clusters[visit_id == df.slice$b]

    dt.b <- dt.b[classification != '']

    dt.b[, visit_id := NULL]

    setnames(dt.b, 2, 'cluster_b')

    setkey(dt.b, 'patient_id')

    dt.merged <- dt.a[dt.b, nomatch = 0]

    tab <- table(dt.merged[, .(cluster_a, cluster_b)])

    chisq.result <- chisq.test(tab, simulate.p.value = TRUE, B = 2000 * multiplier)

    list(
        a = df.slice$a,
        b = df.slice$b,
        result = chisq.result,
        targets = colnames(tab)
    )

}, .progress = 'time')



# Collate the results.

message('Collating results')

dt.p <- rbindlist(llply(chisq.results, function (x) {

    data.table(visit_a = x$a, visit_b = x$b, p = x$result$p.value)

}))

dt.stdres <- rbindlist(llply(chisq.results, function (x) {

	y <- x$result$stdres

	if (is.vector(y)) {

		data.table(visit_a = x$a, visit_b = x$b, cluster_a = '--', cluster_b = x$targets, std_residual = x$result$stdres)

	} else {

	    result <- data.table(visit_a = x$a, visit_b = x$b, melt(x$result$stdres, value.name = 'std_residual'))

	    if (class(result$cluster_a) == 'integer') {

	    	result[, cluster_a := sprintf('%02d', cluster_a)]

	    }

	    if (class(result$cluster_b) == 'integer') {

	    	result[, cluster_b := sprintf('%02d', cluster_b)]

	    }

	    result

	}

}))

dt.stdres[, abs_residual := abs(std_residual)]

dt.stdres[, stars := ifelse(abs_residual > qnorm(0.9995), '***', ifelse(abs_residual > qnorm(0.995), '**', ifelse(abs_residual > qnorm(0.975), '*', '')))]



# Write the outputs.

message('Writing outputs')

write.csv(dt.p, file = args$p_value_output, row.names = FALSE)

write.csv(dt.stdres, file = args$std_residual_output, row.names = FALSE)



message('Done')
