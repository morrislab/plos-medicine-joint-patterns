# Conducts statistics on bootstrapped assignments.

library(argparse)

library(data.table)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.data <- fread(args$input)



# Calculate some statistics. Remember: the SE for a bootstrap is just the SD of
# the sampling distribution!

message('Calculating statistics')

reference.values <- dt.data[threshold == max(threshold), count]

get.stats <- function (counts) {
    
    t.result <- t.test(counts, reference.values, alternative = 'greater')
    
    data.table(mean = mean(counts), se = sd(counts), t = t.result$statistic, p = t.result$p.value)
    
}

dt.stats <- dt.data[, get.stats(count), keyby = .(threshold)]



# Write the output.

message('Writing output')

write.csv(dt.stats, file = args$output, row.names = FALSE)
