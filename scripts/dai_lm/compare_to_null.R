# Compares a nested model to a specified baseline model.

library(argparse)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--model-input', required = TRUE)

parser$add_argument('--null-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

load.data <- function (path) {

	load(path)

	lm.model.res

}

lm.model <- load.data(args$model_input)

lm.null <- load.data(args$null_input)



# Calculate statistics.

message('Calculating statistics')

anova.res <- anova(lm.null, lm.model)

sink(args$output)

cat('F: ', tail(anova.res$F, 1), '\n', sep = '')

cat('P: ', tail(anova.res$`Pr(>F)`, 1), '\n', sep = '')

sink()
