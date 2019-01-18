# Determines the number of factors to use for NMF.

library(argparse)

library(data.table)

library(feather)

# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--k-output', required = TRUE)

parser$add_argument('--k-reduced-output', required = TRUE)

parser$add_argument('--p-output', required = TRUE)

args <- parser$parse_args()

# Load the data.

message('Loading data')

dt.q2 <- read_feather(args$input)

setDT(dt.q2)

# Remove bad runs.

message('Removing bad runs')

dt.q2 <- dt.q2[q2 > -1]

# Calculate the optimal k.

message('Calculating optimal number of factors')

dt.q2.mean <- dt.q2[, .(mean = mean(q2)), keyby = 'k']

k.optimal <- dt.q2.mean[which.max(mean), k]

# Calculate the scaled-back k.

message('Calculating scaled-back number of factors')

k.optimal.q2.samples <- dt.q2[k == k.optimal, q2]

dt.q2.filtered <- dt.q2[k < k.optimal]

get.p.values <- function (k, q2, base.q2) {

    result <- t.test(q2, base.q2)

    data.table(statistic = result$statistic, p = result$p.value)

}

dt.p.values <- dt.q2.filtered[, get.p.values(unique(k), q2, k.optimal.q2.samples), by = 'k']

dt.p.values[, p_bonferroni := p.adjust(p, method = 'bonferroni')]

k.reduced <- k.optimal

if (any(dt.p.values$p_bonferroni >= 0.05)) {

    dt.p.values.filtered <- dt.p.values[p_bonferroni >= 0.05]

    k.reduced <- dt.p.values.filtered[, min(k)]

}

# Write the outputs.

message('Writing output')

cat(k.optimal, file = args$k_output)

cat(k.reduced, file = args$k_reduced_output)

write.csv(dt.p.values, file = args$p_output, row.names = FALSE)

message('Done')
