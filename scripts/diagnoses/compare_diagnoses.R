# Compares diagnoses between the discovery and validation cohorts.

library(argparse)

library(data.table)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--discovery-input', required = TRUE)

parser$add_argument('--validation-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 283971)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.discovery <- fread(args$discovery_input)

dt.validation <- fread(args$validation_input)



# Calculate statistics.

message('Calculating statistics')

p.discovery <- table(dt.discovery$diagnosis)

p.discovery <- p.discovery / sum(p.discovery)

tab.validation <- table(dt.validation$diagnosis)

chisq.res <- chisq.test(tab.validation, p = p.discovery, simulate.p.value = TRUE, B = 20000)



# Write results.

message('Writing results')

sink(args$output)

cat('# Overall\n\n')

print(chisq.res)

cat('\n\n')

cat('# Std. residuals\n\n')

print(chisq.res$stdres)

sink()
