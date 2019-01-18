# Adjust conditional P-values.

library(argparse)
library(data.table)
library(dplyr)
library(dtplyr)

parser <- ArgumentParser()
parser$add_argument('--input', required = TRUE, help = 'the CSV file to read input from')
parser$add_argument('--output', required = TRUE, help = 'the CSV file to write output to')
args <- parser$parse_args()



# Load the data.

message('Loading data')

X <- fread(args$input)



# Adjust P-values.

message('Adjusting P-values')

X <- X %>%
    group_by(classification, reference_site) %>%
    mutate(
        p_adjusted = p.adjust(p, method = 'bonferroni')
    )



# Write output.

message('Writing output')

X %>%
    write.csv(args$output, row.names = FALSE)
