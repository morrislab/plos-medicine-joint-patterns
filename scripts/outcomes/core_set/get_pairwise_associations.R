# Calculates pairwise associations between patient groups on outcomes.

library(argparse)

library(data.table)

library(feather)

library(gtools)

library(plyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the Feather file to read outcomes from')

parser$add_argument('--output', required = TRUE, help = 'the CSV file to output results to')

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Melt the data.

message('Melt the data')

dt.melted <- melt(dt.data, id.vars = c('subject_id', 'classification'), na.rm = TRUE)



# Conduct the pairwise associations.

message('Conducting pairwise associations')

do.pairwise <- function (X) {

	unique.classifications <- sort(unique(X$classification))

	combs <- combinations(length(unique.classifications), 2)

	Y <- rbindlist(alply(combs, 1, function (ab) {

		cls.a <- unique.classifications[ab[1]]

		cls.b <- unique.classifications[ab[2]]

		X.a <- X[classification == cls.a]

		X.b <- X[classification == cls.b]

		test.res <- wilcox.test(X.a$value, X.b$value)

		with(test.res, data.table(cls_a = cls.a, cls_b = cls.b, statistic = statistic, p = p.value))

	}))

	Y[, p_adjusted := p.adjust(p, method = 'b')]

}

dt.result <- dt.melted[, do.pairwise(.SD), by = .(variable)]



# Write the output.

message('Writing output')

write.csv(dt.result, file = args$output, row.names = FALSE)

