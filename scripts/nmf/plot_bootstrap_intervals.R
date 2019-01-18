# Plots bootstrap intervals.

library(argparse)

library(data.table)

library(feather)

library(grid)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE)

parser$add_argument('--figure-output', required = TRUE)

parser$add_argument('--lower-quantile-threshold', type = 'double', default = 0.25)

parser$add_argument('--upper-quantile', type = 'double', default = 0.75)

parser$add_argument('--base-size', type = 'integer', default = 8)

parser$add_argument('--integer-variables', default = FALSE, action = 'store_true')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.bs <- setDT(read_feather(args$input))

if (args$integer_variables) {

	dt.bs[, variable := factor(as.integer(as.character(variable)))]

}



message('Calculating statistics')

dt.bs.stats <- dt.bs[, .(
	ymin = quantile(loading, args$lower_quantile_threshold),
	middle = quantile(loading, 0.5),
	ymax = quantile(loading, args$upper_quantile)
), by = .(factor, variable)]

get.threshold <- function (.SD) {

	.SD[which.max(middle), ymin]

}

dt.bs.thresholds <- dt.bs.stats[, .(threshold = get.threshold(.SD)), keyby = .(factor)]

dt.bs.stats <- setkey(dt.bs.stats, factor)[dt.bs.thresholds]

dt.bs.stats[, above_threshold := ymax >= threshold]



message('Generating plot')

theme_set(theme_classic(base_size = args$base_size) + theme(axis.text = element_text(size = rel(1)), axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5), axis.ticks.length = unit(4.8, 'pt'), strip.text = element_text(size = rel(1), face = 'bold'), strip.background = element_blank(), legend.title = element_text(size = rel(1), face = 'bold'), legend.text = element_text(size = rel(1)), legend.position = 'bottom'))

pl <- ggplot(dt.bs.stats, aes(x = variable)) + facet_grid(factor ~ ., scales = 'free_y', switch = 'y') + geom_hline(yintercept = 0, colour = 'grey') + geom_errorbar(aes(ymin = ymin, ymax = ymax, colour = above_threshold), width = 0.2) + geom_point(aes(y = middle, colour = above_threshold), size = rel(0.5)) + scale_y_continuous(breaks = pretty, expand = c(0.1, 0)) + scale_colour_manual(values = c('grey', 'black'), labels = c('No', 'Yes')) + labs(x = 'Variable', y = 'Basis matrix loading', colour = 'Retained')



message('Writing plot')

ggsave(pl, file = args$figure_output, width = args$figure_width, height = args$figure_height)
