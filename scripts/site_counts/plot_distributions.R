# Plots overlapping distributions of site counts.

library(argparse)

library(data.table)

library(grid)

library(ggplot2)

library(plyr)

library(cowplot)

rm(list = ls())



# Get arguments.

parser <- ArgumentParser()

parser$add_argument('--input', required = TRUE, nargs = '+', help = 'the CSV files to read site counts from')

parser$add_argument('--labels', nargs = '+', help = 'labels for inputs')

parser$add_argument('--output', required = TRUE, help = 'the PDF file to write the output to')

parser$add_argument('--figure-width', type = 'double', default = 7)

parser$add_argument('--figure-height', type = 'double', default = 7)

args <- parser$parse_args()

if (!is.null(args$labels) && length(args$labels) != length(args$input)) {

	stop('the number of --labels must match the number of --inputs')

}



# Load all data.

message('Loading data')

dts.data <- llply(args$input, fread)



# Combine the data.

message('Combining data')

dataset.labels <- if (!is.null(args$labels)) args$labels else seq(dts.data)

dataset.labels <- factor(dataset.labels, levels = dataset.labels)

for (k in seq(args$input)) {

	dts.data[[k]][, dataset := dataset.labels[k]]

}

dt.data <- rbindlist(dts.data)



# Generate the plots.

message('Generating plots')

theme_set(
	theme_classic(base_size = 8) +
		theme(
			panel.spacing = unit(9.6, 'pt'),
			aspect.ratio = 0.625,
			axis.text = element_text(size = rel(1)),
			axis.ticks.length = unit(4.8, 'pt'),
			strip.background = element_blank(),
			strip.text = element_text(size = rel(1), face = 'bold'),
			legend.title = element_text(size = rel(1), face = 'bold'),
			legend.text = element_text(size = rel(1))
		)
)

pl.hist <- ggplot(dt.data, aes(x = count)) +
	facet_grid(dataset ~ ., scales = 'free_y') +
	geom_histogram(bins = 20, fill = grey(0.8)) +
	scale_x_continuous(breaks = pretty, expand = c(0, 0)) +
	scale_y_continuous(breaks = pretty, expand = c(0, 0)) +
	labs(x = 'Site count', y = 'Number of patients') +
	theme(aspect.ratio = 0.3125)

pl.ecdf <- ggplot(dt.data, aes(x = count)) +
	stat_ecdf(aes(colour = dataset)) +
	scale_x_continuous(breaks = pretty) +
	scale_y_continuous(breaks = pretty) +
	labs(x = 'Site count', y = 'f(x)', colour = 'Cohort')



# Combine the plots.

message('Combining plots')

pl.combined <- plot_grid(pl.hist, pl.ecdf, ncol = 1, rel_heights = c(length(dts.data) / 2, 1))



# Write the output.

message('Writing output')

ggsave(args$output, pl.combined, width = args$figure_width, height = args$figure_height)
