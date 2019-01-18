# Compares two Cox proportional hazards models.

library(argparse)

library(survival)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--reference-input', required = TRUE, help = 'the RData file to read the reference model from')

parser$add_argument('--alternative-input', required = TRUE, help = 'the RData file to read the alternative model from')

parser$add_argument('--output', required = TRUE, help = 'the text file to output results to')

args <- parser$parse_args()



# Load the models.

message('Loading models')

load.model <- function (path) {

	n <- load(path)

	get(n)

}

model.reference <- load.model(args$reference_input)

model.alternative <- load.model(args$alternative_input)



# Run the F test to determine if there is an improvement.

message('Running analysis of deviance')

anova.res <- anova(model.reference, model.alternative)



# Write the output.

message('Writing output')

sink(args$output)

print(anova.res)

sink()
