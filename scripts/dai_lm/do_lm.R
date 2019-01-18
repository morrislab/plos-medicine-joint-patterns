# Conducts linear regression to predict disease activity.

library(argparse)

library(data.table)

library(feather)

library(dplyr)

library(dtplyr)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- setDT(read_feather(args$input))

dt.data <- dt.data %>% select(-subject_id)



# Conduct linear regression.

message('Conducting linear regression')

rhs <- paste(lapply(colnames(dt.data %>% select(-dai)), function (j) {

	if (is.numeric(dt.data[[j]])) paste0('scale(', j, ')') else j

}), collapse = ' + ')

f <- paste0('dai ~ ', rhs)

lm.model.res <- lm(as.formula(f), dt.data)

lm.model.null <- lm(dai ~ 1, dt.data)



# Write the output.

message('Writing output')

save(lm.model.res, lm.model.null, file = args$output)

