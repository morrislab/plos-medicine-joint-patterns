# Summarizes time to zero data.

library(argparse)

library(feather)

library(data.table)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Calculate stats.

message('Calculating statistics')

dt.summary <- dt.data[, .(
	n_zero = sum(!is.na(first_zero_visit)),
	n = .N,
	time_to_zero_median = median(first_zero_visit, na.rm = TRUE)
), keyby = .(classification)]



# Write output.

message('Writing output')

write.csv(dt.summary, file = args$output, row.names = FALSE)
