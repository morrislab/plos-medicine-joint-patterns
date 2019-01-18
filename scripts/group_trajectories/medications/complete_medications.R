# Completes missing data.

library(argparse)

library(feather)

library(dplyr)

library(dtplyr)

library(tidyr)

rm(list = ls())

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, help = 'the Feather file to read medication data from')

parser$add_argument('--output', required = TRUE, help = 'the Feather file to write completed medication data to')

args <- parser$parse_args()



# Load the data.

message('Loading data')

df.data <- read_feather(args$input)



# Complete the data.

message('Completing data')

df.data <- df.data %>% group_by(visit_id) %>% complete(subject_id, medication, fill = list(status = FALSE))



# Write the output.

message('Writing output')

write_feather(df.data, args$output)
