# Determines appropriate values to use for NMF.

library(argparse)

library(data.table)

library(feather)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--k-output', required = TRUE)

parser$add_argument('--alpha-output', required = TRUE)

parser$add_argument('--coefficient', type = 'double', default = 1)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.q2 <- setDT(read_feather(args$input))



message('Pruning bad runs')

dt.q2 <- dt.q2[q2 > -1]



message('Generating data')

dt.stats <- dt.q2[, .(
    mean = mean(q2),
    se = sd(q2) / sqrt(.N)
), keyby = .(k, alpha)]

dt.stats.max <- dt.stats[which.max(mean)]

boundary <- dt.stats.max[, mean - args$coefficient * se]

dt.stats[, within_limits := mean >= boundary]

chosen.k <- min(dt.stats[within_limits == TRUE]$k)

chosen.alpha <- head(setorder(dt.stats[k == chosen.k & within_limits], -alpha), 1)$alpha



message('Writing outputs')

cat(chosen.k, file = args$k_output, append = FALSE)

cat(chosen.alpha, file = args$alpha_output, append = FALSE)
