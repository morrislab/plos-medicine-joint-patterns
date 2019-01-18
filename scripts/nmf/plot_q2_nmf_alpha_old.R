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

parser$add_argument('--coefficient', type = 'double', default = 1)

parser$add_argument('--colour-scale', default = FALSE, action = 'store_true')

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.q2 <- read_feather(args$input)

setDT(dt.q2)



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



message('Removing numbers of factors and alpha values whose Q2s are all <0')

dt.stats <- dt.stats[, if (any(mean > 1e-6)) .SD else NULL, by = .(k)]

dt.stats <- dt.stats[, if (any(mean > 1e-6)) .SD else NULL, by = .(alpha)]



message('Plotting data')

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.line.x = element_line(), axis.line.y = element_line(), axis.ticks.length = unit(4.8, 'pt')))

make.colour <- function (r, g, b, alpha) {

    r <- r + (1 - alpha) * (1 - r)

    g <- g + (1 - alpha) * (1 - g)

    b <- b + (1 - alpha) * (1 - b)

    rgb(r, g, b)

}

alpha.breakpoints <- seq(0.25, 1, length.out = 5)

this.scale <- if (args$colour_scale) c(make.colour(0, 1, 0, alpha.breakpoints[1]), make.colour(1, 1, 0, alpha.breakpoints[2]), make.colour(1, 0.65, 0, alpha.breakpoints[3]), make.colour(1, 0, 0, alpha.breakpoints[4]), make.colour(0.625, 0.125, 0.95, alpha.breakpoints[5])) else c(grey(0.85), 'black')

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.line.x = element_line(), axis.line.y = element_line(), axis.ticks.length = unit(4.8, 'pt'), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1))))

pl <- ggplot(dt.stats, aes(x = factor(k), y = factor(alpha))) + geom_tile(aes(fill = mean)) + geom_point(aes(shape = within_limits), colour = 'white') + geom_point(data = dt.stats.max, shape = 1, colour = 'white', size = 2) + labs(x = 'Number of factors', y = 'Alpha', fill = 'Mean\nQ2', shape = 'Within\nmax(mean(Q2))\nminus SE') + scale_x_discrete(expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) + scale_fill_gradientn(colours = this.scale, na.value = 'white', breaks = pretty) + scale_shape_manual(values = c(NA, 3)) + coord_fixed()



message('Writing plot')

ggsave(args$output, width = args$figure_width, height = args$figure_height)

message('Done')

