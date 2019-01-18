# Conducts forward stepwise regression to predict responses in disease activity indicator.

library(argparse)

library(data.table)

library(feather)

library(selectiveInference)

library(plyr)

library(dplyr)

library(dtplyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--seed', type = 'integer', default = 89347934)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))



# Conduct FSR.

message('Running FSR')

set.seed(args$seed)

predictors <- dt.data %>% dplyr::select(-subject_id, -dai)

outcomes <- dt.data$dai

fs.fit <- list(predictors = colnames(predictors), result = fs(as.matrix(predictors), outcomes, maxsteps = 2000, intercept = TRUE, normalize = TRUE))



# Write the output.

message('Writing output')

save(fs.fit, file = args$output)
