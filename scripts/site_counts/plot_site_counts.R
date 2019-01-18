# Plots site counts among the patient groups.

library(argparse)

library(data.table)

library(grid)

library(ggbeeswarm)

library(ggplot2)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--data-input', required = TRUE)

parser$add_argument('--cluster-input', required = TRUE)

parser$add_argument('--output', required = TRUE)

parser$add_argument('--boundary', type = 'double')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()



# Conduct the analysis.

message('Loading data')

dt.data <- fread(args$data_input)

dt.clusters <- fread(args$cluster_input)

setkey(dt.clusters, subject_id)



message('Calculating site counts')

dt.data.melted <- melt(dt.data, id.vars = c('subject_id'))

dt.site.counts <- dt.data.melted[, .(count = sum(value)), keyby = .(subject_id)]



message('Merging data')

dt.merged <- dt.clusters[dt.site.counts]



message('Calculating statistics')

dt.stats <- dt.merged[, .(
	ymin = quantile(count, 0.25),
	y = as.double(median(count)),
	ymax = quantile(count, 0.75)
), by = .(classification)]



message('Generating plot')

set.seed(42427859)

theme_set(theme_classic(base_size = 8) + theme(axis.text = element_text(size = rel(1)), axis.ticks.length = unit(4.8, 'pt')))

pl <- ggplot(dt.merged, aes(x = classification)) +
	geom_violin(aes(y = count), colour = NA, fill = grey(0.8), scale = 'width') +
	geom_quasirandom(aes(y = count), shape = 16, colour = grey(0.6)) +
	geom_pointrange(aes(ymin = ymin, y = y, ymax = ymax), dt.stats, shape = 23, fill = 'white', size = 0.5, fatten = 4) +
	scale_y_continuous(breaks = pretty) +
	labs(x = 'Patient group', y = 'Number of sites involved')

if (!is.null(args$boundary)) {

	pl <- pl + geom_hline(yintercept = args$boundary, linetype = 'dotted')

}



message('Writing plot')

ggsave(args$output, width = args$figure_width, height = args$figure_height)

