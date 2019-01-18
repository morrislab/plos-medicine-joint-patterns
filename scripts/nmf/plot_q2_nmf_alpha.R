# Plots values of Q2 from the NMF analysis.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Load the data.

message('Loading data')

dt.q2 <- read_feather(args$input)

setDT(dt.q2)



# Prune off the chart values.

message('Pruning bad runs')

dt.q2 <- dt.q2[q2 > -1]



message('Generating data')

dt.stats <- dt.q2[, .(
    mean = mean(q2),
    ciw = sd(q2) / sqrt(.N),
    alpha_log2 = log2(alpha)
), keyby = .(alpha)]

alpha.0.mean <- dt.stats[alpha == 0, mean]

alpha.0.ciw <- dt.stats[alpha == 0, ciw]

dt.stats[, `:=`(
	alpha_0_mean = alpha.0.mean,
	alpha_0_ciw = alpha.0.ciw
)]

dt.plot <- dt.stats[alpha > 0]



message('Plotting data')

dt.stats.max <- dt.stats[which.max(mean)]

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.line.x = element_line(), axis.line.y = element_line(), axis.ticks.length = unit(4.8, 'pt')))

pl <- ggplot(dt.plot, aes(x = alpha_log2)) + geom_ribbon(aes(ymin = alpha_0_mean - alpha_0_ciw, ymax = alpha_0_mean + alpha_0_ciw), fill = grey(0.8)) + geom_hline(aes(yintercept = alpha_0_mean), linetype = 'dashed') + geom_line(aes(y = mean)) + geom_errorbar(aes(ymin = mean - ciw, ymax = mean + ciw), width = 0.2) + geom_point(aes(y = mean), shape = 21, fill = 'white') + labs(x = 'log2(Regularization coefficient)', y = expression(italic(Q) ^ 2)) + scale_x_continuous(breaks = pretty) + scale_y_continuous(breaks = pretty)



message('Writing plot')

ggsave(args$output, width = args$figure_width, height = args$figure_height)



message('Done')

