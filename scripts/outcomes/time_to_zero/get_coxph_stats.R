# Outputs statistics from the Cox proportional hazards model.

library(argparse)

library(survival)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the model.

message('Loading model')

load(args$input)



# Output the statistics.

message('Writing statistics')

sink(args$output)

cat('# Tests of proportional hazards assumption\n\n')

print(cox.zph(coxph.model))

cat('\n\n# ANOVA\n\n')

print(anova(coxph.model))

cat('\n\n# Model coefficients\n\n')

summary.res <- summary(coxph.model)

print(summary.res)

cat('\n\n# R-squared\n\n')

print(summary.res$rsq['rsq'])

sink()
